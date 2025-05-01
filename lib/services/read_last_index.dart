import 'package:shared_preferences/shared_preferences.dart';

// Class responsible for reading the last saved index from SharedPreference

class ReadLastIndex {
  // Static method to execute the reading process
  static Future<int?> execute() async {
    // Obtain an instance of SharedPreference
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();

    // Retrieve the last saved index from SharedPreferences
    return sharedPreferences.getInt('index');
  }
}
