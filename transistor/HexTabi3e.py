"""
Kristen Kamouh - useless script to replace # with 0x00 in a text file.
done only for csc 312 to use in mips assembly, otherwise will never be used again.
"""

import os


def replace_hash_with_0x(fileEl2reye, fileElKhales):
    """Replace # with 0x00
    Returns True on success, False on failure.
    """
    try:
        with open(fileEl2reye, 'r', encoding='utf-8') as input_file:
            with open(fileElKhales, 'w', encoding='utf-8') as output_file:
                for line in input_file:
                    new_line = line.replace('#', '0x00')
                    output_file.write(new_line)
        print("akal")
        return True
    except FileNotFoundError:
        print("ma akal: sar chi: ", fileEl2reye)
        return False
    except OSError as e:
        print("ma akal: OS khachab:", e)
        return False


def _sanitize_path(p):
    """remove "" mnl path"""
    if p is None:
        return p
    p = p.strip()
    # remove surrounding single or double quotes if the user typed them
    if (p.startswith('"') and p.endswith('"')) or (p.startswith("'") and p.endswith("'")):
        p = p[1:-1]
    p = os.path.expanduser(p)
    p = os.path.normpath(p)
    return p


if __name__ == '__main__':
    input_file = _sanitize_path(input("hatele directory txt file: "))
    output_file = _sanitize_path(input("hatele wen sayevlak file l jdid li fiyo 0x (hat .txt bi ekher l esem): "))
    replace_hash_with_0x(input_file, output_file)
