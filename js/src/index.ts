/**
 * The main state.
 * */
export class ZigJS {
  /**
   * Set this to the memory of your WebAssembly instance prior to making
   * any Wasm calls that might interface with JS.
   * */
  memory?: ArrayBuffer;

  /**
   * Returns the import object that should be merged with your import
   * object when instantiating your wasm instance. This injects the required
   * functions into the wasm environment.
   * */
  importObject(): ImportObject {
    return {
      "zig-js": {
        valueGet: this.valueGet.bind(this),
      },
    };
  }

  /**
   * Get a value from the JS environment.
   * */
  protected valueGet(ref: number, ptr: number, len: number): number {
    return 42;
  }
}

export interface ImportObject {
  "zig-js": {
    valueGet: (ref: number, ptr: number, len: number) => number;
  };
};

const nan_prefix = 0x7FF8_0000;
