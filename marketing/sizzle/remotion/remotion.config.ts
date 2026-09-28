import {Config} from '@remotion/cli/config';

// Codec / CRF / pixel format are passed on the command line (see README) so audio-only renders also work.
Config.setVideoImageFormat('jpeg');
Config.setJpegQuality(95);
Config.setAudioBitrate('320k');
Config.setConcurrency(6);
Config.setOverwriteOutput(true);
