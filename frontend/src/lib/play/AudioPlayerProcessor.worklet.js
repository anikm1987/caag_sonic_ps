/**
 * Copyright 2025 Amazon.com, Inc. and its affiliates. All Rights Reserved.
 *
 * Licensed under the Amazon Software License (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *   http://aws.amazon.com/asl/
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

// Audio sample buffer to minimize reallocations
class ExpandableBuffer {
  constructor() {
    this.buffer = new Float32Array(24000);
    this.readIndex = 0;
    this.writeIndex = 0;
    this.underflowedSamples = 0;
    this.isInitialBuffering = true;
    this.initialBufferLength = 24000;
    this.lastWriteTime = 0;
  }

  logTimeElapsedSinceLastWrite() {
    const now = Date.now();
    if (this.lastWriteTime !== 0) {
      const elapsed = now - this.lastWriteTime;
    }
    this.lastWriteTime = now;
  }

  write(samples) {
    this.logTimeElapsedSinceLastWrite();
    if (this.writeIndex + samples.length > this.buffer.length) {
      if (samples.length <= this.readIndex) {
        const subarray = this.buffer.subarray(this.readIndex, this.writeIndex);
        this.buffer.set(subarray);
      } else {
        const newLength =
          (samples.length + this.writeIndex - this.readIndex) * 2;
        const newBuffer = new Float32Array(newLength);
        newBuffer.set(this.buffer.subarray(this.readIndex, this.writeIndex));
        this.buffer = newBuffer;
      }
      this.writeIndex -= this.readIndex;
      this.readIndex = 0;
    }
    this.buffer.set(samples, this.writeIndex);
    this.writeIndex += samples.length;
    if (this.writeIndex - this.readIndex >= this.initialBufferLength) {
      this.isInitialBuffering = false;
    }
  }

  read(destination) {
    let copyLength = 0;
    if (!this.isInitialBuffering) {
      copyLength = Math.min(
        destination.length,
        this.writeIndex - this.readIndex
      );
    }
    destination.set(
      this.buffer.subarray(this.readIndex, this.readIndex + copyLength)
    );
    this.readIndex += copyLength;

    if (copyLength < destination.length) {
      destination.fill(0, copyLength);
      this.underflowedSamples += destination.length - copyLength;
    }

    if (copyLength === 0) {
      this.isInitialBuffering = true;
    }
  }

  clearBuffer() {
    this.readIndex = 0;
    this.writeIndex = 0;
  }
}

class AudioPlayerProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.playbackBuffer = new ExpandableBuffer();
    this.port.onmessage = (event) => {
      if (event.data.type === "audio") {
        this.playbackBuffer.write(event.data.audioData);
      } else if (event.data.type === "initial-buffer-length") {
        this.playbackBuffer.initialBufferLength = event.data.bufferLength;
      } else if (event.data.type === "barge-in") {
        this.playbackBuffer.clearBuffer();
      }
    };
  }

  process(inputs, outputs, parameters) {
    const output = outputs[0][0];
    this.playbackBuffer.read(output);

    // Send back played samples
    this.port.postMessage({
      type: "played-audio",
      samples: Array.from(output),
    });

    return true;
  }
}

registerProcessor("audio-player-processor", AudioPlayerProcessor);
