import json, urllib.request, io, os, glob, shutil, sys
from PIL import Image
os.chdir(os.path.expanduser('~/mnt/mo/imagens_produtos'))
os.makedirs('_substituidas', exist_ok=True)
L = json.load(open(sys.argv[1]))
res = {}
for i, u, motivo in L:
    try:
        b = urllib.request.urlopen(urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0'}), timeout=30).read()
        im = Image.open(io.BytesIO(b)); im.load()
    except Exception as e:
        res[i] = f'falhou: {e}'[:80]; continue
    ext = {'JPEG': 'jpg', 'PNG': 'png', 'WEBP': 'webp', 'GIF': 'gif'}.get(im.format, 'jpg')
    atuais = glob.glob(i + '.*')
    if motivo.startswith('substituir') and atuais:
        try: velho = min(Image.open(atuais[0]).size)
        except Exception: velho = 0
        if min(im.size) <= velho:
            res[i] = f'mantida atual ({velho}px >= {min(im.size)}px)'; continue
        for a in atuais: shutil.move(a, '_substituidas/' + a)
    elif atuais:
        for a in atuais: shutil.move(a, '_substituidas/' + a)
    open(f'{i}.{ext}', 'wb').write(b)
    res[i] = f'ok {im.size[0]}x{im.size[1]}'
# Liber lata usa a foto da Liber garrafa
g = glob.glob('260-*.*')
if g and not glob.glob('261-*.*'):
    shutil.copy(g[0], '261-cerveja-liber-lata-350ml.' + g[0].rsplit('.', 1)[1]); res['261'] = 'copiada da 260'
print(json.dumps(res, ensure_ascii=False))
