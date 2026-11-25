import sys
try:
    import pypdf
    print("pypdf ok", pypdf.__version__)
except Exception as e:
    print("no pypdf:", e)
try:
    import fitz
    print("pymupdf ok")
except Exception as e:
    print("no fitz:", e)
