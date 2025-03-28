import 'package:flutter/material.dart';
import '../../../coach/race_screen/widgets/runner_record.dart';

class BibRecordsProvider with ChangeNotifier {
  final List<RunnerRecord> _bibRecords = [];
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  bool _isKeyboardVisible = false;

  List<RunnerRecord> get bibRecords => _bibRecords;
  List<TextEditingController> get controllers => _controllers;
  List<FocusNode> get focusNodes => _focusNodes;
  bool get isKeyboardVisible => _isKeyboardVisible;

  void addBibRecord(RunnerRecord record) {
    _bibRecords.add(record);
    final controller = TextEditingController(text: record.bib);
    _controllers.add(controller);
    
    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (focusNode.hasFocus != _isKeyboardVisible) {
        _isKeyboardVisible = focusNode.hasFocus;
        notifyListeners();
      }
    });
    _focusNodes.add(focusNode);
    
    notifyListeners();
  }

  void updateBibRecord(int index, String bibNumber) {
    _bibRecords[index].bib = bibNumber;
    notifyListeners();
  }

  void removeBibRecord(int index) {
    _bibRecords.removeAt(index);
    _controllers[index].dispose();
    _controllers.removeAt(index);
    _focusNodes[index].dispose();
    _focusNodes.removeAt(index);
    notifyListeners();
  }

  void clearBibRecords() {
    _bibRecords.clear();
    for (var controller in _controllers) {
      controller.dispose();
    }
    _controllers.clear();
    for (var node in _focusNodes) {
      node.dispose();
    }
    _focusNodes.clear();
    notifyListeners();
  }
}
