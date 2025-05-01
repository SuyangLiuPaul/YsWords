import os


def scan_and_dump(folder_path, output_file):
    with open(output_file, 'w', encoding='utf-8') as out:
        for root, dirs, files in os.walk(folder_path):
            level = root.replace(folder_path, '').count(os.sep)
            indent = ' ' * 4 * level
            folder_name = os.path.basename(root)
            out.write(f"{indent}[Folder] {folder_name}/\n")

            subindent = ' ' * 4 * (level + 1)
            for file in sorted(files):
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, folder_path)
                out.write(f"{subindent}- {file}\n")

                # 写入文件内容
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        code = f.read()
                except UnicodeDecodeError:
                    code = '[Binary or Non-UTF-8 file, skipped]\n'

                out.write(f"\n{'=' * 80}\nFILE: {rel_path}\n{'=' * 80}\n")
                out.write(code + '\n\n')


if __name__ == "__main__":
    base_dir = os.path.join(os.path.dirname(__file__), 'build', 'web')
    output_path = os.path.join(os.path.dirname(__file__), 'web_code_dump.txt')

    if os.path.exists(base_dir):
        scan_and_dump(base_dir, output_path)
        print(f"Code scan complete. Output written to: {output_path}")
    else:
        print("build/web directory not found.")
