function run_bamq(pairs_csv, model_root, out_csv, shard, n_shards)
% RUN_BAMQ  Step 3b -- score every reference/test pair with the combined
% GPSMq + BAM-Q audio quality model of Flessner et al. (2019).
%
%   run_bamq(PAIRS_CSV, MODEL_ROOT, OUT_CSV, SHARD, N_SHARDS)
%
% MODEL_ROOT is the root of the unmodified `combinedaudioqualitymodel`
% distribution.  The model itself is called exactly as in the distribution's
% Example_combAudioQual.m, including the two presentation-level adjustments:
%
%   +8 dB  before GPSMqBin           (monaural front end)
%   -15 dB before BAMQ4Public_restruct (binaural front end)
%
% Those constants are the ones used for the originally submitted analysis and
% are retained so that model outputs remain directly comparable across the two
% rounds.  Because every stimulus has already been normalised to a common
% integrated loudness, they now correspond to the same presentation level for
% every stimulus, which was not the case before.
%
% The runner is shard-aware and resumable: OUT_CSV is appended row by row and
% pairs already present are skipped.

    if nargin < 4, shard = 0;    end
    if nargin < 5, n_shards = 1; end
    if ischar(shard),    shard    = str2double(shard);    end
    if ischar(n_shards), n_shards = str2double(n_shards); end

    addpath(genpath(model_root));

    P = readtable(pairs_csv, 'TextType', 'string', 'Delimiter', ',');
    idx = find(mod((0:height(P)-1)', n_shards) == shard);

    done = strings(0, 1);
    if isfile(out_csv)
        D = readtable(out_csv, 'TextType', 'string', 'Delimiter', ',');
        if ~isempty(D), done = D.pair_id; end
    else
        fid = fopen(out_csv, 'w');
        fprintf(fid, ['pair_id,item,anchor,variant,is_anchor,SNR_dc,SNR_ac,' ...
                      'SNR_dc_fix,SNR_ac_fix,OPM,OPM_fix,binQ,ILDdiff,ITDdiff,' ...
                      'IVSdiff,overall_measure,seconds\n']);
        fclose(fid);
    end

    for k = 1:numel(idx)
        row = P(idx(k), :);
        if any(done == row.pair_id)
            continue
        end

        t0 = tic;
        [R, fsR] = audioread(char(row.ref_path));
        [T, fsT] = audioread(char(row.test_path));
        if fsR ~= fsT
            error('run_bamq:fs', 'sample-rate mismatch for %s', row.pair_id);
        end
        if size(R, 1) ~= size(T, 1)
            error('run_bamq:len', 'length mismatch for %s', row.pair_id);
        end
        fs = fsR;

        % --- monaural GPSMq (presentation level as in the reference example)
        st = GPSMqBin(R * 10^(8/20), T * 10^(8/20), fs);

        % --- binaural BAM-Q
        [binQ, ILDdiff, ITDdiff, IVSdiff] = ...
            BAMQ4Public_restruct(R * 10^(-15/20), T * 10^(-15/20), fs);

        % --- combined overall measure
        om = combine_binQ_OPM(st.OPM_fix(:, 1), binQ(:, 1));
        dt = toc(t0);

        fid = fopen(out_csv, 'a');
        fprintf(fid, '%s,%s,%s,%s,%d,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.1f\n', ...
            row.pair_id, row.item, row.anchor, row.variant, row.is_anchor, ...
            st.SNR_dc, st.SNR_ac, st.SNR_dc_fix, st.SNR_ac_fix, ...
            st.OPM, st.OPM_fix, binQ, ILDdiff, ITDdiff, IVSdiff, om, dt);
        fclose(fid);

        fprintf('[shard %d] %d/%d %s  overall=%.5f (%.0fs)\n', ...
                shard, k, numel(idx), row.pair_id, om, dt);
    end
end
