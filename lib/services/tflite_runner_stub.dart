class TfliteRunner {
  bool get isLoaded => false;

  Future<bool> loadModel(String assetPath) async {
    return false;
  }

  Future<List<double>> runImageClassification(
    Future<List<List<List<List<num>>>>> Function({
      required int width,
      required int height,
      required bool isQuantizedUint8,
    }) buildInput,
    int numClasses,
  ) async {
    throw UnsupportedError('Yerel TFLite çıkarımı Web platformunda desteklenmiyor.');
  }

  void dispose() {}
}

