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

import ObjectExt from "./../util/ObjectsExt";
const AudioPlayerWorkletUrl = new URL(
  "./AudioPlayerProcessor.worklet.js",
  import.meta.url
).toString();

export default class AudioPlayer {
  constructor() {
    this.onAudioPlayedListeners = [];
    this.initialized = false;
  }

  addEventListener(event, callback) {
    if (event === "onAudioPlayed") {
      this.onAudioPlayedListeners.push(callback);
    } else {
      console.error("Unsupported event type: " + event);
    }
  }

  async start() {
    this.audioContext = new AudioContext({ sampleRate: 24000 });
    this.analyser = this.audioContext.createAnalyser();
    this.analyser.fftSize = 512;

    await this.audioContext.audioWorklet.addModule(AudioPlayerWorkletUrl);
    this.workletNode = new AudioWorkletNode(
      this.audioContext,
      "audio-player-processor"
    );
    this.workletNode.connect(this.analyser);
    this.analyser.connect(this.audioContext.destination);

    // Listen for played audio samples
    this.workletNode.port.onmessage = (event) => {
      if (event.data.type === "played-audio") {
        const samples = new Float32Array(event.data.samples);
        this.onAudioPlayedListeners.forEach((listener) => listener(samples));
      }
    };

    this.#maybeOverrideInitialBufferLength();
    this.initialized = true;
  }

  bargeIn() {
    this.workletNode?.port.postMessage({ type: "barge-in" });
  }

  stop() {
    if (ObjectExt.exists(this.audioContext)) this.audioContext.close();
    if (ObjectExt.exists(this.analyser)) this.analyser.disconnect();
    if (ObjectExt.exists(this.workletNode)) this.workletNode.disconnect();

    this.initialized = false;
    this.audioContext = null;
    this.analyser = null;
    this.workletNode = null;
  }

  #maybeOverrideInitialBufferLength() {
    const params = new URLSearchParams(window.location.search);
    const value = params.get("audioPlayerInitialBufferLength");
    if (value !== null) {
      const bufferLength = parseInt(value);
      if (!isNaN(bufferLength)) {
        this.workletNode.port.postMessage({
          type: "initial-buffer-length",
          bufferLength: bufferLength,
        });
      } else {
        console.error("Invalid audioPlayerInitialBufferLength value:", value);
      }
    }
  }

  playAudio(samples) {
    if (!this.initialized) {
      console.error("The audio player is not initialized. Call init() first.");
      return;
    }
    this.workletNode.port.postMessage({
      type: "audio",
      audioData: samples,
    });
  }

  getSamples() {
    if (!this.initialized) return null;
    const bufferLength = this.analyser.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    this.analyser.getByteTimeDomainData(dataArray);
    return [...dataArray].map((e) => e / 128 - 1);
  }

  getVolume() {
    if (!this.initialized) return 0;
    const bufferLength = this.analyser.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    this.analyser.getByteTimeDomainData(dataArray);
    let normSamples = [...dataArray].map((e) => e / 128 - 1);
    let sum = 0;
    for (let i = 0; i < normSamples.length; i++) {
      sum += normSamples[i] * normSamples[i];
    }
    return Math.sqrt(sum / normSamples.length);
  }
}
