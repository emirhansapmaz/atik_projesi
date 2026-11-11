import 'package:tflite_flutter/tflite_flutter.dart';

class TfliteRunner {
  Interpreter? _interpreter;

  bool get isLoaded => _interpreter != null;

  Future<bool> loadModel(String assetPath) async {
    try {
      _interpreter = await Interpreter.fromAsset(assetPath);
      return true;
    } catch (_) {
      _interpreter?.close();
      _interpreter = null;
      return false;
    }
  }

  Future<List<double>> runImageClassification(
    Future<List<List<List<List<num>>>>> Function({
      required int width,
      required int height,
      required bool isQuantizedUint8,
    }) buildInput,
    int defaultNumClasses,
  ) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('TFLite Interpreter yüklenmemiş.');
    }

    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);

    final inputShape = inputTensor.shape;
    final int height = inputShape.length >= 3 ? inputShape[1] : 224;
    final int width = inputShape.length >= 3 ? inputShape[2] : 224;
    final bool isQuantizedInput = inputTensor.type == TensorType.uint8;

    final input = await buildInput(
      width: width,
      height: height,
      isQuantizedUint8: isQuantizedInput,
    );

    final outputShape = outputTensor.shape;
    final int numClasses =
        outputShape.isNotEmpty ? outputShape.last : defaultNumClasses;
    final bool isQuantizedOutput = outputTensor.type == TensorType.uint8;

    final List<List<num>> output = List.generate(
      1,
      (_) => isQuantizedOutput
          ? List<int>.filled(numClasses, 0)
          : List<double>.filled(numClasses, 0.0),
    );

    interpreter.run(input, output);

    final scores = output.first;
    return List<double>.generate(scores.length, (i) {
      return isQuantizedOutput
          ? scores[i].toDouble() / 255.0
          : scores[i].toDouble();
    });
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

