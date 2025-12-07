// processor.js
class PCMProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.ratio = sampleRate / 16000;
  }

  process(inputs) {
    const input = inputs[0];
    if (!input || input.length === 0) return true;

    const inputChannelData = input[0];

    // Downsample if needed
    const outLen = Math.floor(inputChannelData.length / this.ratio);
    const downsampled = new Float32Array(outLen);
    for (let i = 0; i < outLen; i++) {
      downsampled[i] = inputChannelData[Math.floor(i * this.ratio)];
    }

    // Convert to Int16
    const int16 = new Int16Array(downsampled.length);
    for (let i = 0; i < downsampled.length; i++) {
      const s = Math.max(-1, Math.min(1, downsampled[i]));
      int16[i] = s < 0 ? s * 32768 : s * 32767;
    }

    // Send to main thread
    this.port.postMessage(int16.buffer, [int16.buffer]);
    return true;
  }
}

registerProcessor('pcm-processor', PCMProcessor);
