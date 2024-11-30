import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart'; // Add this import


Future<String> predictDigitsFromPicture(XFile picture) async {
  final url = Uri.parse('http://127.0.0.1:5000/run-predict_digits_from_picture');

  // Create a multipart request
  var request = http.MultipartRequest('POST', url);
  request.files.add(await http.MultipartFile.fromPath('image', picture.path));

  // Send the request
  var response = await request.send();

  // Read and process the response
  if (response.statusCode == 200) {
    final responseBody = await response.stream.bytesToString();
    final data = jsonDecode(responseBody);
    print('Result from Python: ${data['result']}');
    return data['result'];
  } else {
    print('Failed to call Python function: ${response.statusCode}');
  }
  return '';
}