import os


def scan_and_save(lib_path, output_file):
    with open(output_file, 'w', encoding='utf-8') as out_file:
        # Add pubspec.yaml
        pubspec_path = os.path.join(os.path.dirname(lib_path), "pubspec.yaml")
        if os.path.exists(pubspec_path):
            out_file.write(f"\n{'='*80}\nFILE: pubspec.yaml\n{'='*80}\n")
            with open(pubspec_path, 'r', encoding='utf-8') as pubspec:
                out_file.write(pubspec.read() + '\n')

        # Walk through lib directory
        for root, _, files in os.walk(lib_path):
            for file in files:
                if file.endswith(".dart"):
                    full_path = os.path.join(root, file)
                    relative_path = os.path.relpath(full_path, lib_path)
                    out_file.write(
                        f"\n{'='*80}\nFILE: {relative_path}\n{'='*80}\n")
                    with open(full_path, 'r', encoding='utf-8') as f:
                        out_file.write(f.read() + '\n')


if __name__ == "__main__":
    lib_folder = "./lib"
    output_txt = "lib_source_dump.txt"
    scan_and_save(lib_folder, output_txt)
    print(f"✅ All Dart source code and pubspec.yaml saved to: {output_txt}")
