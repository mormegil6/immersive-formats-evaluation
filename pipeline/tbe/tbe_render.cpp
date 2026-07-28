// Offline TBE -> binaural renderer built on the Audio360 SDK.
//
// The FB360 Spatial Workstation only renders TBE binaurally from inside a DAW,
// which makes that step of the pipeline manual, unversioned and -- as this study
// discovered the hard way -- silently fallible: a bypassed Spatialiser produces
// a file that looks like a binaural render but is actually channels 1 and 2 of
// the TBE stream passed through untouched.  This tool performs the same decode
// headlessly and deterministically so the step can be scripted and verified.
//
// It drives the engine with the audio device DISABLED and pulls the mix through
// getAudioMix(), which is the SDK's supported offline path.  Audio is pushed
// through a SpatDecoderQueue rather than a SpatDecoderFile so that production
// and consumption are synchronous: there is no streaming thread to underrun,
// and the result is bit-reproducible across runs.
//
// I/O is raw interleaved float32 so that no WAV parsing is needed here; the
// Python wrapper handles headers, and keeps this translation unit small enough
// to audit.
//
//   tbe_render <in.raw> <out.raw> <inChannels> [sampleRate] [blockFrames]
//
// inChannels: 10 for TBE_8_2 (8 TBE + 2 head-locked), 8 for TBE_8.

#include "TBE_AudioEngine.h"

#include <cstdio>
#include <cstdlib>
#include <vector>

using namespace TBE;

int main(int argc, char** argv) {
  if (argc < 4) {
    std::fprintf(stderr,
                 "usage: tbe_render <in.raw> <out.raw> <inChannels> "
                 "[sampleRate] [blockFrames]\n");
    return 2;
  }
  const char* inPath = argv[1];
  const char* outPath = argv[2];
  const int inCh = std::atoi(argv[3]);
  const float sampleRate = (argc > 4) ? (float)std::atof(argv[4]) : 48000.0f;
  const int block = (argc > 5) ? std::atoi(argv[5]) : 512;

  ChannelMap map;
  if (inCh == 10) {
    map = ChannelMap::TBE_8_2;
  } else if (inCh == 8) {
    map = ChannelMap::TBE_8;
  } else {
    std::fprintf(stderr, "unsupported channel count %d (expected 8 or 10)\n", inCh);
    return 2;
  }

  std::FILE* fi = std::fopen(inPath, "rb");
  if (!fi) { std::perror("open input"); return 1; }
  std::fseek(fi, 0, SEEK_END);
  const long bytes = std::ftell(fi);
  std::fseek(fi, 0, SEEK_SET);
  const size_t totalSamples = (size_t)(bytes / (long)sizeof(float));
  std::vector<float> in(totalSamples);
  if (std::fread(in.data(), sizeof(float), totalSamples, fi) != totalSamples) {
    std::fprintf(stderr, "short read on input\n"); std::fclose(fi); return 1;
  }
  std::fclose(fi);
  const long frames = (long)(totalSamples / (size_t)inCh);

  EngineInitSettings settings;
  settings.audioSettings.sampleRate = sampleRate;
  settings.audioSettings.bufferSize = block;
  settings.audioSettings.deviceType = AudioDeviceType::DISABLED;

  AudioEngine* engine = nullptr;
  if (TBE_CreateAudioEngine(engine, settings) != EngineError::OK || !engine) {
    std::fprintf(stderr, "failed to create audio engine\n"); return 1;
  }
  // Static, forward-facing listener: this is a fixed-head binaural render, to
  // match how every other format in the study was rendered.
  engine->setListenerRotation(0.0f, 0.0f, 0.0f);

  SpatDecoderQueue* queue = nullptr;
  if (engine->createSpatDecoderQueue(queue) != EngineError::OK || !queue) {
    std::fprintf(stderr, "failed to create spat decoder queue\n"); return 1;
  }

  engine->start();
  queue->play();

  std::FILE* fo = std::fopen(outPath, "wb");
  if (!fo) { std::perror("open output"); return 1; }

  std::vector<float> out((size_t)block * 2);
  long inPos = 0;       // frames already enqueued
  long outFrames = 0;   // stereo frames written
  // Render past the end of the input so the renderer's own latency and HRTF
  // tail are captured; the conditioning stage aligns and crops afterwards.
  const long tail = (long)(sampleRate * 1.0f);
  const long target = frames + tail;

  while (outFrames < target) {
    const long freeFrames = (long)queue->getFreeSpaceInQueue(map) / inCh;
    if (freeFrames > 0) {
      long n = frames - inPos;
      if (n > freeFrames) n = freeFrames;
      if (n > 0) {
        queue->enqueueData(in.data() + (size_t)inPos * inCh, (int)(n * inCh), map);
        inPos += n;
      } else {
        // Input exhausted: feed silence so the tail flushes through.
        long pad = freeFrames > block ? block : freeFrames;
        if (pad > 0) queue->enqueueSilence((int)(pad * inCh), map);
      }
    }

    if (engine->getAudioMix(out.data(), block * 2, 2) != EngineError::OK) {
      std::fprintf(stderr, "getAudioMix failed at frame %ld\n", outFrames);
      break;
    }
    long w = block;
    if (outFrames + w > target) w = target - outFrames;
    std::fwrite(out.data(), sizeof(float), (size_t)w * 2, fo);
    outFrames += w;
  }

  std::fclose(fo);
  TBE_DestroyAudioEngine(engine);
  std::fprintf(stderr, "rendered %ld frames (input %ld + %ld tail)\n",
               outFrames, frames, tail);
  return 0;
}
