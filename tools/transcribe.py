"""Usage: transcribe.py <path to .ogg> -> prints the recognized text to stdout."""
import os
import sys

os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")

import av
import numpy as np
from faster_whisper import WhisperModel


def decode(path):
    # Decoded by hand: faster-whisper's own decode_audio breaks on av 19
    # (av.open() no longer accepts metadata_errors).
    resampler = av.AudioResampler(format="s16", layout="mono", rate=16000)
    chunks = []
    with av.open(path, mode="r") as container:
        for frame in container.decode(audio=0):
            for out in resampler.resample(frame):
                chunks.append(out.to_ndarray().reshape(-1))
        for out in resampler.resample(None):
            chunks.append(out.to_ndarray().reshape(-1))
    if not chunks:
        return np.zeros(0, dtype=np.float32)
    return np.concatenate(chunks).astype(np.float32) / 32768.0


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: transcribe.py <audio file>")
    audio = decode(sys.argv[1])
    model = WhisperModel("small", device="cpu", compute_type="int8")
    segments, _ = model.transcribe(audio, language="ru", beam_size=1, vad_filter=True)
    sys.stdout.reconfigure(encoding="utf-8")
    print(" ".join(s.text.strip() for s in segments))


if __name__ == "__main__":
    main()
