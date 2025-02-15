import 'package:flutter/material.dart';

class BibRecord {
  String bibNumber;
  List<double> confidences;
  String name;
  String school;
  Map<String, bool> flags;
  
  BibRecord({
    this.bibNumber = '',
    this.confidences = const [],
    this.name = '',
    this.school = '',
  }) : flags = {
    'duplicate_bib_number': false,
    'not_in_database': false,
    'low_confidence_score': false,
  };

  bool get hasErrors => flags.values.any((flag) => flag);
  bool get isValid => !hasErrors && bibNumber.isNotEmpty;
}

class BibRecordsProvider with ChangeNotifier {
  final List<BibRecord> _bibRecords = [];
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  bool _isKeyboardVisible = false;

  List<BibRecord> get bibRecords => _bibRecords;
  List<TextEditingController> get controllers => _controllers;
  List<FocusNode> get focusNodes => _focusNodes;
  bool get isKeyboardVisible => _isKeyboardVisible;

  void addBibRecord(BibRecord record) {
    _bibRecords.add(record);
    final controller = TextEditingController(text: record.bibNumber);
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
    _bibRecords[index].bibNumber = bibNumber;
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