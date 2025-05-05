import os
import subprocess


def convert_docx_to_pdf(input_dir, output_dir=None):
    # Default to same directory if output_dir is not specified
    if output_dir is None:
        output_dir = input_dir

    for filename in os.listdir(input_dir):
        if filename.lower().endswith(".docx"):
            input_path = os.path.join(input_dir, filename)
            try:
                subprocess.run([
                    "/Applications/LibreOffice.app/Contents/MacOS/soffice",  # full path to soffice
                    "--headless",
                    "--convert-to", "pdf",
                    "--outdir", output_dir,
                    input_path
                ], check=True)
                print(f"Converted: {filename}")
            except subprocess.CalledProcessError:
                print(f"Failed to convert: {filename}")


if __name__ == "__main__":
    input_directory = "/Users/paul/Desktop/2025"  # Change this to your actual path
    convert_docx_to_pdf(input_directory)
