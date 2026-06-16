#!/usr/bin/env python3
"""
Convert WAV file to CAS format for Basic Master Jr.

CAS format:
  - Header: 380 bytes of 0x7F (silence)
  - Audio samples: 8-bit unsigned (0-255) at 19200 Hz
  - Conversion: sample > 0x80 → HIGH, sample <= 0x80 → LOW
"""

import struct
import sys
import os


def find_wav_data_start(wav_samples, threshold=10):
    """Find the start of actual audio data (skip initial silence)."""
    for i in range(len(wav_samples)):
        val = wav_samples[i]
        # Look for values significantly different from silence
        if val not in [0x00, 0x7f, 0x80] and (val < 0x70 or val > 0x90):
            return i
    return 0


def convert_wav_to_cas(wav_path, cas_path, target_rate=8000, max_samples=None):
    """
    Convert WAV file to CAS format.
    
    Args:
        wav_path: Path to input WAV file
        cas_path: Path to output CAS file
        target_rate: Target sample rate in Hz (default: 8000)
        max_samples: Maximum number of output samples (None = use all WAV data)
    """
    print(f"Converting {wav_path} to {cas_path}...")
    
    # Read WAV file
    with open(wav_path, 'rb') as f:
        wav_header = f.read(44)
        
        if wav_header[0:4] != b'RIFF':
            print("ERROR: Invalid WAV file (missing RIFF header)")
            return False
        
        # Parse WAV header
        sample_rate = struct.unpack('<I', wav_header[24:28])[0]
        bits_per_sample = struct.unpack('<H', wav_header[34:36])[0]
        channels = struct.unpack('<H', wav_header[22:24])[0]
        
        print(f"WAV: {sample_rate} Hz, {bits_per_sample}-bit, {channels} channel(s)")
        
        # Find data chunk
        pos = 12
        data_size = 0
        while pos < len(wav_header):
            chunk_id = wav_header[pos:pos+4]
            if chunk_id == b'data':
                data_size = struct.unpack('<I', wav_header[pos+4:pos+8])[0]
                break
            pos += 8
        
        # Read audio data
        f.seek(44)
        if bits_per_sample == 8:
            wav_samples = list(f.read(data_size))
        elif bits_per_sample == 16:
            wav_samples = []
            for i in range(data_size // 2):
                sample = struct.unpack('<h', f.read(2))[0]
                # Convert signed 16-bit to unsigned 8-bit (0-255)
                # WAV 16-bit: -32768 to 32767
                # CAS 8-bit: 0 to 255
                # Map: -32768 -> 0, 0 -> 128, 32767 -> 255
                wav_samples.append((sample + 32768) >> 8)
        else:
            print(f"ERROR: Unsupported bits per sample: {bits_per_sample}")
            return False
        
        print(f"Read {len(wav_samples)} samples from WAV")
    
    # Resample to target rate (8000 Hz)
    ratio = sample_rate / target_rate
    print(f"Resampling: {sample_rate} Hz → {target_rate} Hz (ratio: {ratio:.2f}x)")
    
    # Find start of actual audio data (skip initial silence)
    data_start = find_wav_data_start(wav_samples)
    if data_start > 0:
        print(f"Skipping {data_start} samples of initial silence")
    
    # Calculate output samples
    available_wav_samples = len(wav_samples) - data_start
    if max_samples is not None:
        # Limit to specified number of samples (e.g., to match original CAS file size)
        max_output_samples = min(max_samples, int(available_wav_samples / ratio))
        print(f"Limiting output to {max_samples} samples (to match reference CAS file)")
    else:
        # Use all available WAV data
        max_output_samples = int(available_wav_samples / ratio)
    
    cas_samples = []
    for i in range(max_output_samples):
        wav_idx_float = data_start + i * ratio
        wav_idx = int(wav_idx_float)
        frac = wav_idx_float - wav_idx
        if wav_idx + 1 < len(wav_samples):
            # Linear interpolation between adjacent samples
            s0 = wav_samples[wav_idx]
            s1 = wav_samples[wav_idx + 1]
            interpolated = int(s0 + frac * (s1 - s0) + 0.5)
            cas_samples.append(max(0, min(255, interpolated)))
        elif wav_idx < len(wav_samples):
            cas_samples.append(wav_samples[wav_idx])
        else:
            break
    
    print(f"Resampled to {len(cas_samples)} samples at {target_rate} Hz")
    print(f"  Duration: {len(cas_samples) / target_rate:.2f} seconds")
    
    # Write CAS file
    with open(cas_path, 'wb') as f:
        # Write header: 380 bytes of 0x7F
        header = bytes([0x7F] * 380)
        f.write(header)
        
        # Write audio samples
        f.write(bytes(cas_samples))
    
    print(f"✓ CAS file written: {cas_path}")
    print(f"  Header: 380 bytes")
    print(f"  Audio: {len(cas_samples)} samples")
    print(f"  Total: {380 + len(cas_samples)} bytes")
    
    return True


def main():
    if len(sys.argv) < 2:
        print("Usage: wav2cas.py <input.wav> [output.cas] [--max-samples N] [--rate Hz]")
        print("  If output.cas is not specified, it will be generated from input.wav")
        print("  --max-samples N: Limit output to N samples (to match reference CAS file)")
        print("  --rate Hz: Target sample rate (default: 19200)")
        sys.exit(1)
    
    wav_path = sys.argv[1]
    
    if not os.path.exists(wav_path):
        print(f"ERROR: File not found: {wav_path}")
        sys.exit(1)
    
    # Parse arguments
    cas_path = None
    max_samples = None
    target_rate = 19200
    
    i = 2
    while i < len(sys.argv):
        if sys.argv[i] == '--max-samples' and i + 1 < len(sys.argv):
            max_samples = int(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == '--rate' and i + 1 < len(sys.argv):
            target_rate = int(sys.argv[i + 1])
            i += 2
        elif cas_path is None:
            cas_path = sys.argv[i]
            i += 1
        else:
            i += 1
    
    if cas_path is None:
        # Generate output filename from input
        base = os.path.splitext(wav_path)[0]
        cas_path = base + '.cas'
    
    if not convert_wav_to_cas(wav_path, cas_path, target_rate=target_rate, max_samples=max_samples):
        sys.exit(1)


if __name__ == '__main__':
    main()

