from PIL import Image

im = Image.open(r"D:\mygame\assets\materials\Glass.png").convert("RGBA")
px = im.load()
W, H = im.size
alphas = []
rgb = []
for y in range(H):
    for x in range(W):
        r, g, b, a = px[x, y]
        alphas.append(a)
        rgb.append((r, g, b))
alphas.sort()
n = len(alphas)
print("Glass.png %dx%d  alpha min=%d p10=%d p50=%d p90=%d max=%d mean=%.1f" % (
    W, H, alphas[0], alphas[n//10], alphas[n//2], alphas[9*n//10], alphas[-1], sum(alphas)/n))
print("  -> as float: mean alpha = %.3f, p50 = %.3f" % (sum(alphas)/n/255.0, alphas[n//2]/255.0))
print()
print("final opacity when used as chapter_03 does:")
print("  mezz railing  alpha=0.30 -> 0.30 * %.3f = %.4f  (%.1f%%)" % (sum(alphas)/n/255.0, 0.30*sum(alphas)/n/255.0, 0.30*sum(alphas)/n*100))
print("  shop window   alpha=0.24 -> 0.24 * %.3f = %.4f  (%.1f%%)" % (sum(alphas)/n/255.0, 0.24*sum(alphas)/n/255.0, 0.24*sum(alphas)/n*100))
print()
print("=== RGB of the brightest 5% (the highlight strokes) ===")
pairs = sorted(zip(alphas, rgb), reverse=True)[:200]
from collections import Counter
c = Counter([p[1] for p in pairs])
for col, cnt in c.most_common(6):
    print("   ", col, cnt)
