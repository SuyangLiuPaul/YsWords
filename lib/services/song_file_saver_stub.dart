// Neither web nor io — no such platform ships, but the analyzer wants
// every branch of the conditional import to resolve.
import 'song_file_saver.dart' show SaveOutcome, SaveFailed;

bool get songFileSaverSupported => false;
Future<SaveOutcome> songFileSaverSave(
        {required String url, required String fileName, required String mime}) async =>
    const SaveFailed('unsupported platform');
