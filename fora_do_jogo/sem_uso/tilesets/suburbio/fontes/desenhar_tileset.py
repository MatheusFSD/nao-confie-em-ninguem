"""Arte determinística em pixels inteiros. Recriar: python3 desenhar_tileset.py.
Requer Pillow apenas para recriar os PNGs; o jogo usa os arquivos exportados.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
import math
import random

OUT = Path(__file__).resolve().parents[1]
OUT.mkdir(parents=True, exist_ok=True)
T = 32
P = {
    'ink':'#1c2d2b', 'shadow':'#293b34', 'deep':'#354b40',
    'green0':'#3d594b', 'green1':'#55745d', 'green2':'#759174', 'green3':'#a0af89',
    'mint0':'#4c6d66', 'mint1':'#718e7b', 'mint2':'#9db39b',
    'cream0':'#89866a', 'cream1':'#b0aa86', 'cream2':'#d3c8a0', 'cream3':'#e4d9b6',
    'wood0':'#4e4433', 'wood1':'#70563b', 'wood2':'#97734b', 'wood3':'#ba945e',
    'rust0':'#624536', 'rust1':'#8c5c40', 'rust2':'#b17a50', 'rust3':'#cf9965',
    'gray0':'#3c4946', 'gray1':'#59655a', 'gray2':'#7c8572', 'gray3':'#a5ab91',
    'blue0':'#304e56', 'blue1':'#456a72', 'blue2':'#69898b', 'blue3':'#96ad9f',
    'sand0':'#534f37', 'sand1':'#78734c', 'sand2':'#a09865', 'sand3':'#c0b881',
    'red':'#a95f46', 'light':'#d4b975', 'black':'#142420',
}
C = {k:tuple(bytes.fromhex(v[1:]))+(255,) for k,v in P.items()}
ATLAS = {}
RECORDS = []

def col(c): return C.get(c,c)
def new(w,h): return Image.new('RGBA',(w,h),(0,0,0,0))
def rect(im,box,c): ImageDraw.Draw(im).rectangle(box,fill=col(c))
def line(im,pts,c,w=1): ImageDraw.Draw(im).line(pts,fill=col(c),width=w)
def ellipse(im,box,c,outline=None): ImageDraw.Draw(im).ellipse(box,fill=col(c),outline=col(outline) if outline else None)
def poly(im,pts,c): ImageDraw.Draw(im).polygon(pts,fill=col(c))
def frame(im,b,c0,c1,c2):
    x,y,r,bottom=b
    rect(im,b,c0)
    rect(im,(x+1,y+1,r-1,bottom-1),c1)
    line(im,[(x+1,bottom-1),(x+1,y+1),(r-1,y+1)],c2)
def grain(im,b,base,lo,hi,seed=0,spacing=6):
    frame(im,b,lo,base,hi)
    x,y,r,bottom=b
    rng=random.Random(seed)
    for yy in range(y+5,bottom-1,spacing):
        line(im,[(x+2,yy),(r-2,yy)],lo)
        if r-x>12:
            xx=rng.randint(x+3,r-7)
            line(im,[(xx,yy+2),(min(xx+7,r-2),yy+2)],hi)

def register(sheet,name,xy,sz,im,collision=None,**extra):
    assert im.size==(sz[0]*T,sz[1]*T), (name,im.size,sz)
    atlas=ATLAS[sheet]
    origin=(xy[0]*T,xy[1]*T)
    assert origin[0]+im.width<=atlas.width and origin[1]+im.height<=atlas.height
    atlas.paste(im,origin)
    RECORDS.append(dict(source=sheet,name=name,atlas=list(xy),size=list(sz),collision=collision or [],**extra))

def floor(kind,v):
    im=new(T,T); rng=random.Random(391+v*19)
    if kind in ['ceramica_bege','azulejo_verde','azulejo_banheiro']:
        palette={'ceramica_bege':('cream0','cream1','cream2'),'azulejo_verde':('mint0','mint1','mint2'),'azulejo_banheiro':('gray2','cream2','cream3')}[kind]
        step=16 if kind!='azulejo_banheiro' else 8
        rect(im,(0,0,31,31),palette[0])
        for y in range(0,T,step):
            for x in range(0,T,step):
                rect(im,(x+1,y+1,x+step-1,y+step-1),palette[1])
                line(im,[(x+2,y+2),(x+step-2,y+2)],palette[2])
        if v==1:
            line(im,[(2,17),(4,17)],palette[0])
            rect(im,(23,28,24,28),palette[2])
        if v==2:
            line(im,[(7,6),(11,10),(9,13),(14,17)],palette[0])
        if v==3:
            for _ in range(9):
                x,y=rng.randrange(2,30),rng.randrange(2,30)
                rect(im,(x,y,x+1,y),palette[0])
    elif kind=='ladrilho_floral':
        rect(im,(0,0,31,31),'cream0')
        rect(im,(1,1,31,31),'cream2')
        line(im,[(0,8),(8,0)],'mint0')
        line(im,[(24,31),(31,24)],'mint0')
        for dx,dy in [(0,-7),(7,0),(0,7),(-7,0)]:
            poly(im,[(16+dx,10+dy),(21+dx,16+dy),(16+dx,22+dy),(11+dx,16+dy)],'mint1')
        rect(im,(14,14,18,18),'cream2')
        rect(im,(15,15,17,17),'rust1')
        if v==1: rect(im,(27,4,28,5),'cream0')
        if v>1: line(im,[(3,25),(7,23),(10,27)],'cream0')
        if v==3: rect(im,(22,23,24,24),'cream0')
    elif kind=='taco':
        rect(im,(0,0,31,31),'wood0')
        for j in range(4):
            b=(1,j*8+1,31,j*8+7)
            grain(im,b,'wood2' if (v+j)%3 else 'wood1','wood1','wood3',v+j,4)
        if v%2: im=im.transpose(Image.Transpose.ROTATE_90)
    elif kind=='telha':
        rect(im,(0,0,31,31),'rust0')
        for x in range(0,32,8):
            rect(im,(x+1,0,x+6,31),'rust1')
            line(im,[(x+2,0),(x+2,31)],'rust2',2)
            line(im,[(x+3,0),(x+3,31)],'rust3')
            for y in [0,16]: line(im,[(x+1,y),(x+6,y)],'rust0')
        if v:
            for _ in range(v+1):
                xx,yy=rng.randrange(2,30),rng.randrange(3,29)
                rect(im,(xx,yy,xx+1,yy),'rust0')
    else:
        palette={'cimento':('gray1','gray2','gray0'),'terra':('sand0','sand1','wood0'),
                 'grama_rala':('deep','green1','green0'),'asfalto':('gray0','gray1','shadow'),
                 'calcada':('gray2','gray3','gray1'),'sarjeta':('gray1','gray2','gray0')}[kind]
        rect(im,(0,0,31,31),palette[0])
        for _ in range(24 if kind!='asfalto' else 13):
            x,y=rng.randrange(1,31),rng.randrange(1,31)
            rect(im,(x,y,x+(1 if kind in ['terra','grama_rala'] else 0),y),palette[rng.choice([1,2])])
        if kind in ['cimento','calcada']:
            line(im,[(0,31),(0,0),(31,0)],palette[2])
            if kind=='calcada': line(im,[(2,30),(2,2),(30,2)],palette[1])
        if kind=='sarjeta':
            rect(im,(0,0,31,6),'gray2');line(im,[(0,1),(31,1)],'gray3')
            line(im,[(0,7),(31,7)],'shadow',2)
        if v==2 and kind in ['cimento','calcada','asfalto']:
            line(im,[(10,3),(12,9),(8,15),(11,21),(7,28)],palette[2])
            line(im,[(8,15),(4,13)],palette[2])
    return im

def wall(mask,kind):
    # A parede ocupa a célula inteira. O mask controla só as bordas expostas.
    # Assim a borda física/visual coincide com o início do móvel adjacente.
    colors=[('green1','green2','green0'),('gray2','gray3','gray1'),('rust1','rust2','rust0')][kind]
    im=new(T,T)
    for y in range(T):
        for x in range(T):
            c=colors[0]
            if kind==2 and (y%8==0 or (x+(8 if (y//8)%2 else 0))%16==0): c=colors[2]
            if (y==0 and not mask&1) or (x==0 and not mask&8): c=colors[1]
            if (y==31 and not mask&4) or (x==31 and not mask&2): c=colors[2]
            im.putpixel((x,y),C[c])
    return im

def furniture(name,w,h):
    im=new(w,h); cx=w//2;cy=h//2
    if name.startswith('cama'):
        grain(im,(0,0,w-1,h-1),'wood1','wood0','wood2',3)
        frame(im,(8,9,w-9,h-8),'cream0','cream2','cream3')
        frame(im,(12,13,w-13,31),'cream0','cream2','cream3')
        line(im,[(15,17),(w-17,17)],'cream3')
        green=name=='cama_verde'
        pal=('green0','green1','green2') if green else ('rust0','rust1','rust2')
        frame(im,(9,37,w-10,h-10),*pal)
        for yy in range(42,h-12,7):
            line(im,[(11,yy),(w-12,yy)],pal[2])
            if yy%2: line(im,[(11,yy+1),(w-12,yy+1)],pal[0])
        rect(im,(10,35,w-11,41),'cream1')
        line(im,[(12,38),(w-13,38)],'cream3')
    elif name.startswith('sofa') or name=='poltrona':
        if name=='sofa_vertical':
            return furniture('sofa_horizontal',h,w).transpose(Image.Transpose.ROTATE_90)
        frame(im,(0,0,w-1,h-1),'green0','green1','green2')
        frame(im,(7,7,w-8,17),'green0','green2','green3')
        count=3 if name.startswith('sofa') else 1
        cw=(w-18)//count
        for i in range(count):
            xx=9+i*cw
            frame(im,(xx,20,xx+cw-3,h-12),'green0','green1','green2')
            line(im,[(xx+3,h-15),(xx+cw-6,h-15)],'green2')
            rect(im,(xx+cw//2,cy+4,xx+cw//2+1,cy+5),'green0')
        for xx in [4,w-12]:frame(im,(xx,17,xx+7,h-8),'green0','green2','green3')
        if name=='sofa_horizontal':
            frame(im,(w-30,23,w-15,37),'sand0','cream1','cream2')
            line(im,[(w-27,26),(w-18,34)],'cream0')
    elif name in ['guarda_roupa','comoda','estante','armario_cozinha','rack']:
        grain(im,(0,0,w-1,h-1),'wood2','wood0','wood3',5)
        # Tampo horizontal; gavetas e portas verticais ficam ocultas.
        line(im,[(4,h-6),(w-5,h-6)],'wood1')
        if name=='estante':
            rect(im,(9,8,25,18),'cream0');line(im,[(11,10),(22,10)],'cream2')
    elif name in ['mesa_redonda','mesa_retangular','mesa_cozinha']:
        if name=='mesa_redonda':
            ellipse(im,(0,0,w-1,h-1),'wood0');ellipse(im,(3,3,w-4,h-4),'wood2')
            ellipse(im,(8,7,w-9,h-10),'wood3',outline='wood1')
        else:grain(im,(0,0,w-1,h-1),'wood2','wood0','wood3',4)
        ellipse(im,(cx-18,cy-18,cx+18,cy+18),'cream1')
        for a in range(0,360,30):
            x=cx+round(math.cos(math.radians(a))*17);y=cy+round(math.sin(math.radians(a))*17)
            ellipse(im,(x-2,y-2,x+2,y+2),'cream2')
            im.putpixel((x,y),C['wood2'])
        ellipse(im,(cx-12,cy-12,cx+12,cy+12),'cream2')
        ellipse(im,(cx-5,cy-5,cx+5,cy+5),'rust1')
        ellipse(im,(cx-3,cy-4,cx+3,cy+2),'sand2')
    elif name in ['tv_aparador','radio_aparador']:
        grain(im,(0,0,w-1,h-1),'wood1','wood0','wood2',2)
        if name=='tv_aparador':
            # CRT: traseira afunilada, tampa, respiros e só a aresta da tela.
            poly(im,[(18,4),(45,4),(52,23),(52,27),(11,27),(11,23)],'ink')
            poly(im,[(20,5),(43,5),(49,22),(14,22)],'gray0')
            line(im,[(20,5),(43,5),(49,22)],'gray1')
            for xx in range(23,43,3):line(im,[(xx,9),(xx+1,15)],'black')
            line(im,[(13,24),(50,24)],'gray1')
            line(im,[(17,26),(44,26)],'blue0')
            rect(im,(47,26,48,26),'red')
        else:
            rect(im,(8,5,w-9,h-6),'cream2')
            frame(im,(17,12,w-15,22),'ink','gray0','gray1')
            line(im,[(23,12),(23,8),(42,8),(42,12)],'gray2')
            line(im,[(20,12),(12,2)],'gray3')
            ellipse(im,(39,14,43,18),'gray3');ellipse(im,(22,14,25,17),'cream0')
            rect(im,(29,15,35,16),'sand2')
            line(im,[(19,21),(w-17,21)],'black')
    elif name in ['pia_bancada','pia_banheiro','tanque','balcao']:
        frame(im,(0,0,w-1,h-1),'gray1','cream1','cream3')
        if name!='balcao':
            bw=min(28,w-10)
            frame(im,(5,7,5+bw,h-8),'gray2','mint0','mint2')
            rect(im,(8,10,2+bw,h-11),'gray1')
            ellipse(im,(15,h//2+2,18,h//2+5),'ink')
            line(im,[(18,4),(18,11),(21,11)],'gray3',2)
        if w>50:
            for xx in range(40,w-9,4):line(im,[(xx,9),(xx,h-10)],'cream0')
            ellipse(im,(w-23,8,w-10,21),'cream3',outline='cream0')
    elif name=='fogao':
        frame(im,(0,0,w-1,h-1),'gray1','cream2','cream3')
        for xx,yy in [(10,9),(22,9),(10,21),(22,21)]:
            ellipse(im,(xx-5,yy-5,xx+5,yy+5),'gray0')
            ellipse(im,(xx-2,yy-2,xx+2,yy+2),'gray2')
        ellipse(im,(17,4,27,14),'gray2',outline='gray0')
        line(im,[(25,9),(31,9)],'ink',2)
        for xx in [9,15,21]:rect(im,(xx,27,xx+1,27),'gray0')
    elif name in ['geladeira','maquina_lavar']:
        frame(im,(0,0,w-1,h-1),'gray1','cream1','cream3')
        if name=='geladeira':
            # Tampo único: nem portas nem puxador frontal visíveis.
            frame(im,(2,2,w-3,h-3),'cream0','cream1','cream2')
            line(im,[(3,h-4),(w-4,h-4)],'cream0')
            for xx in range(6,w-5,3):rect(im,(xx,2,xx,4),'gray1')
            rect(im,(w-9,7,w-7,8),'cream2')
        else:
            frame(im,(7,8,w-8,h-8),'gray0','gray2','gray3')
            ellipse(im,(10,11,w-11,h-10),'mint0')
            rect(im,(22,5,24,6),'mint0')
    elif name=='vaso_sanitario':
        frame(im,(5,5,26,18),'gray2','cream2','cream3')
        ellipse(im,(5,15,26,51),'gray2')
        ellipse(im,(6,15,25,47),'cream2')
        ellipse(im,(10,20,21,40),'mint0')
        ellipse(im,(12,22,20,36),'mint1')
        rect(im,(20,9,23,10),'gray1')
    elif name=='box_chuveiro':
        for y in range(4,h-4,8):
            for x in range(4,w-4,8):
                frame(im,(x,y,x+7,y+7),'mint0','mint2','cream2')
        frame(im,(42,41,50,49),'gray0','gray1','gray2')
        for xx in range(44,50,2):line(im,[(xx,43),(xx,48)],'shadow')
        line(im,[(4,4),(59,4),(59,59)],'gray3',2)
        line(im,[(31,4),(31,12)],'gray0',2)
        ellipse(im,(27,10,35,16),'gray3',outline='gray1')
    elif name in ['cadeira_madeira','cadeira_plastica']:
        pal=('wood0','wood2','wood3') if name=='cadeira_madeira' else ('gray2','cream2','cream3')
        frame(im,(6,7,25,26),*pal)
        rect(im,(5,2,26,5),pal[0]);line(im,[(6,3),(25,3)],pal[2])
        for xx in [7,24]:line(im,[(xx,4),(xx,9)],pal[0],2)
    elif name=='ventilador':
        # Ventilador de pedestal: disco vertical visto pela aresta, sem hélice frontal.
        ellipse(im,(7,15,25,30),'gray0');ellipse(im,(9,17,23,28),'mint0')
        line(im,[(16,12),(16,23)],'gray2',3)
        frame(im,(12,3,21,12),'gray0','mint0','gray1')
        frame(im,(3,9,29,14),'gray0','gray2','gray3')
        for xx in range(5,29,3):line(im,[(xx,10),(xx,13)],'gray0')
        rect(im,(15,5,18,6),'mint2')
    elif name=='filtro_barro':
        ellipse(im,(5,5,27,27),'rust0');ellipse(im,(7,7,25,25),'rust1')
        ellipse(im,(9,9,23,23),'rust2');ellipse(im,(11,11,21,21),'rust3')
        ellipse(im,(14,14,18,18),'rust0');rect(im,(15,27,17,29),'cream0')
    elif name in ['espada_sao_jorge','samambaia','bananeira']:
        ellipse(im,(cx-9,cy-9,cx+9,cy+9),'rust0');ellipse(im,(cx-7,cy-7,cx+7,cy+7),'sand0')
        for i in range(9):
            a=i*2.4;ln=(w//2-3)-(i%3)*2
            x=cx+round(math.cos(a)*ln);y=cy+round(math.sin(a)*ln)
            if name=='espada_sao_jorge':
                poly(im,[(cx-1,cy),(x,y),(cx+2,cy+2)],'green2')
                line(im,[(cx,cy),(x,y)],'sand2')
            else:
                line(im,[(cx,cy),(x,y)],'green1',3)
                for t in [.4,.6,.8]:
                    xx=round(cx+(x-cx)*t);yy=round(cy+(y-cy)*t)
                    line(im,[(xx-3,yy+2),(xx,yy),(xx+3,yy-2)],'green2',2)
    elif name in ['tapete_croche','capacho','tapete_banheiro']:
        b=(3,4,w-4,h-5);rect(im,b,'sand0')
        for y in range(5,h-5,3):line(im,[(4,y),(w-5,y)],'cream1')
        for x in range(5,w-5,4):line(im,[(x,3),(x,h-3)],'sand2')
        for y in [8,h-9]:line(im,[(4,y),(w-5,y)],'rust1',2)
        if name=='tapete_croche':
            for x in range(12,w-10,12):
                poly(im,[(x,cy-8),(x+5,cy),(x,cy+8),(x-5,cy)],'cream2')
    elif name=='balde':
        ellipse(im,(6,6,26,26),'blue0');ellipse(im,(7,7,25,25),'blue2')
        ellipse(im,(10,10,22,22),'blue0')
        line(im,[(7,16),(25,16)],'gray3')
    return im

def exterior(name,w,h):
    im=new(w,h);cx=w//2;cy=h//2
    if name=='casinha_cachorro':
        # O telhado oculta a fachada e a entrada.
        for yy in range(2,h-2,8):
            for xx in range(2,w-2,8):
                frame(im,(xx,yy,min(xx+7,w-3),min(yy+7,h-3)),'rust0','rust1','rust2')
        line(im,[(cx,2),(cx,h-3)],'rust3',3)
        line(im,[(2,2),(w-3,2)],'rust2')
    elif name=='potes':
        for x in [8,23]:
            ellipse(im,(x-6,10,x+6,22),'gray0');ellipse(im,(x-5,9,x+5,20),'gray3')
            ellipse(im,(x-3,11,x+3,18),'blue1' if x==8 else 'wood2')
    elif name=='varal':
        line(im,[(2,23),(w-3,23)],'gray2')
        for i,x in enumerate(range(10,w-25,29)):
            c=['cream2','blue2','mint2','cream1'][i%4]
            # Roupa vertical: só a dobra superior e ondulações estreitas.
            poly(im,[(x,21),(x+7,20),(x+14,22),(x+22,21),(x+22,25),(x+15,26),(x+7,24),(x,25)],c)
            line(im,[(x+1,22),(x+7,21),(x+14,23),(x+21,22)],'gray2')
            for xx in [x+2,x+18]:rect(im,(xx,21,xx+1,25),'wood2')
    elif name=='mangueira':
        for r in [13,18,23]:ImageDraw.Draw(im).arc((cx-r,cy-r,cx+r,cy+r),25,353,fill=C['green0'],width=3)
        line(im,[(cx+20,cy+12),(w-5,h-9),(w-14,h-4)],'green1',3)
        line(im,[(w-15,h-4),(w-12,h-4)],'sand2',3)
    elif name=='caixa_agua':
        ellipse(im,(4,4,w-5,h-5),'blue0')
        ellipse(im,(7,7,w-8,h-8),'blue1');ellipse(im,(11,11,w-12,h-12),'blue2')
        ellipse(im,(15,15,w-16,h-16),'blue1');rect(im,(cx-7,cy-2,cx+5,cy+1),'blue0')
        rect(im,(cx-6,cy-3,cx+4,cy-2),'blue3')
    elif name=='tijolos_empilhados':
        for y in [9,17]:
            for x in range(4,w-15,17):
                frame(im,(x,y,x+15,y+7),'rust0','rust1','rust3')
                for xx in range(x+3,x+14,4):rect(im,(xx,y+3,xx+1,y+4),'rust0')
    elif name=='canteiro':
        frame(im,(1,6,w-2,h-7),'gray0','rust1','rust2');rect(im,(4,9,w-5,h-10),'sand0')
        for x in range(16,w-5,23):
            sub=furniture('espada_sao_jorge',32,32);im.alpha_composite(sub,(x-16,0))
    elif name=='saco_lixo':
        poly(im,[(9,5),(22,4),(28,10),(29,22),(22,28),(10,29),(4,22),(3,11)],'ink')
        for end in [(8,8),(25,10),(25,23),(9,25),(6,16)]:line(im,[(16,16),end],'gray0')
        poly(im,[(13,12),(18,14),(21,12),(20,17),(17,19),(12,17)],'gray1')
    elif name=='lixeira':
        frame(im,(0,0,31,31),'blue0','blue1','blue2')
        frame(im,(6,5,26,26),'blue0','blue2','blue3')
        for yy in [10,15,20]:line(im,[(9,yy),(23,yy)],'blue1')
        rect(im,(13,13,19,16),'blue0');line(im,[(14,13),(18,13)],'blue3')
        for xx in [8,22]:rect(im,(xx,2,xx+2,4),'gray0')
    elif name=='poste':
        ellipse(im,(9,5,23,19),'gray0');ellipse(im,(10,4,22,16),'gray2')
        line(im,[(16,11),(16,47)],'gray1',5);line(im,[(15,12),(15,47)],'gray3')
        # Braço horizontal e topo da luminária; a lâmpada fica embaixo.
        frame(im,(8,44,24,55),'gray0','gray2','gray3')
        line(im,[(11,47),(21,47)],'gray1')
    elif name=='poca':
        pts=[(3,20),(14,15),(29,17),(42,10),(69,13),(76,18),(w-4,20),(w-12,25),(23,26)]
        poly(im,pts,'gray0');line(im,[(17,18),(28,19),(43,14),(67,16)],'blue1')
        line(im,[(41,23),(62,23)],'gray2')
    elif name in ['bueiro','tampa_bueiro']:
        if name=='bueiro':frame(im,(4,8,w-5,h-7),'gray0','gray1','gray2')
        else:ellipse(im,(3,3,28,28),'gray0');ellipse(im,(5,4,26,25),'gray1')
        for x in range(8,w-7,5):line(im,[(x,11),(x,h-11)],'ink',2)
        line(im,[(7,cy),(w-8,cy)],'gray2')
    elif name in ['portao_fechado','portao_aberto']:
        if name=='portao_aberto':return exterior('portao_fechado',h,w).transpose(Image.Transpose.ROTATE_90)
        rect(im,(0,14,w-1,17),'mint0');line(im,[(0,14),(w-1,14)],'gray2')
        for x in range(3,w-1,6):rect(im,(x,13,x+1,18),'gray1')
        rect(im,(w-13,16,w-9,17),'rust1')
    elif name=='fios':
        for yy in [8,15,23]:line(im,[(0,yy),(w//3,yy+3),(w*2//3,yy+3),(w-1,yy)],'ink')
    elif name.startswith('rachadura'):
        line(im,[(4,4),(w//3,h//3),(w//3-3,h//2),(w//2,h//2+3),(w-5,h-4)],'gray0')
        line(im,[(w//2,h//2+3),(w//2+10,h//2-7)],'gray0')
    elif name=='papeis':
        poly(im,[(8,10),(19,8),(22,17),(10,21)],'cream1');line(im,[(10,12),(17,11)],'cream0')
        poly(im,[(19,22),(25,20),(27,24),(21,26)],'gray3')
    elif name in ['folhas','pedrinhas','mato','mancha']:
        rng=random.Random(41)
        for _ in range(10):
            x,y=rng.randrange(4,27),rng.randrange(5,27)
            if name=='mato':line(im,[(x,y+4),(x-2,y),(x+1,y+2)],'green1')
            else:rect(im,(x,y,x+rng.randrange(1,4),y+1),'sand1' if name=='folhas' else 'gray1')
    elif name.startswith('meio_fio'):
        rect(im,(0,0,31,8),'gray1');rect(im,(0,1,31,5),'gray2');line(im,[(0,1),(31,1)],'gray3')
        if name.endswith('baixo'):im=im.transpose(Image.Transpose.ROTATE_180)
        if name.endswith('esquerda'):im=im.transpose(Image.Transpose.ROTATE_90)
        if name.endswith('direita'):im=im.transpose(Image.Transpose.ROTATE_270)
    elif name=='degraus':
        for y in [3,11,19]:frame(im,(2,y,w-3,y+7),'gray1','gray2','gray3')
    elif name=='telhado_zinco':
        rect(im,(1,1,w-2,h-2),'gray0')
        for x in range(3,w-3,6):
            rect(im,(x,2,x+3,h-3),'gray2');line(im,[(x+1,2),(x+1,h-3)],'gray3')
            for y in [8,h-10]:im.putpixel((x+1,y),C['rust0'])
    else: return furniture(name,w,h)
    return im

def build():
    ATLAS.update(pisos=new(256,192),paredes=new(256,256),moveis=new(512,256),quintal_rua=new(512,288))
    floors=['ceramica_bege','azulejo_verde','taco','ladrilho_floral','cimento','terra','grama_rala','asfalto','calcada','sarjeta','azulejo_banheiro','telha']
    for k,kind in enumerate(floors):
        for v in range(4):register('pisos',f'{kind}_{v+1}',((k%2)*4+v,k//2),(1,1),floor(kind,v))
    for kind,name in enumerate(['reboco_verde','muro_cimento','tijolo_aparente']):
        for mask in range(16):
            boxes=[[0,0,32,32]]
            register('paredes',f'{name}_{mask:02d}',(mask%8,kind*2+mask//8),(1,1),wall(mask,kind),boxes,terrain_set=kind,mask=mask)
    specials=['janela_grade_h','janela_grade_v','porta_madeira_h','porta_madeira_v','soleira_h','soleira_v','grade_h','grade_v','janela_fechada_h','janela_fechada_v','porta_aberta_h','porta_aberta_v','janela_banheiro_h','janela_banheiro_v','coluna_verde','coluna_cimento']
    for i,name in enumerate(specials):
        im=new(32,32); boxes=[]
        if name.startswith('coluna'):
            im=wall(0,0 if i==14 else 1);boxes=[[0,0,32,32]]
        else:
            vertical=name.endswith('_v')
            if name.startswith('soleira'):
                frame(im,(0,0,31,31),'cream0','cream1','cream2')
                line(im,[(16,1),(16,30)],'cream0')
            elif name.startswith('porta_aberta'):
                frame(im,(0,0,31,31),'cream0','cream1','cream2')
                rect(im,(0,0,3,31),'wood0');line(im,[(1,0),(1,31)],'wood2');boxes=[[0,0,4,32]]
            elif name.startswith('porta_madeira'):
                frame(im,(0,0,31,31),'cream0','cream1','cream2')
                rect(im,(0,14,31,17),'wood0');line(im,[(0,14),(31,14)],'wood2')
                rect(im,(26,17,28,18),'light');boxes=[[0,14,32,4]]
            else:
                if not name.startswith('grade'):im=wall(10,0)
                rect(im,(0,12,31,19),'mint0')
                line(im,[(0,12),(31,12)],'mint2')
                line(im,[(0,19),(31,19)],'green0')
                for x in range(3,32,6):rect(im,(x,14,x+1,17),'gray3')
                if name.startswith('janela_fechada'):
                    rect(im,(0,14,31,17),'wood1');line(im,[(0,14),(31,14)],'wood3')
                boxes=[[0,0,32,32]] if not name.startswith('grade') else [[0,12,32,8]]
            if vertical:
                im=im.transpose(Image.Transpose.ROTATE_90)
                boxes=[[b[1],32-b[0]-b[2],b[3],b[2]] for b in boxes]
        register('paredes',name,(i%8,6+i//8),(1,1),im,boxes)
    props=[
        ('cama_verde',0,0,2,3),('cama_terracota',2,0,2,3),('sofa_horizontal',4,0,3,2),('sofa_vertical',7,0,2,3),('poltrona',9,0,2,2),('guarda_roupa',11,0,3,1),('comoda',11,1,2,1),
        ('mesa_redonda',0,3,2,2),('mesa_retangular',2,3,2,2),('tv_aparador',4,3,2,1),('radio_aparador',6,3,2,1),('pia_bancada',8,3,3,1),('fogao',11,3,1,1),('geladeira',12,3,1,1),('vaso_sanitario',13,3,1,2),('box_chuveiro',14,3,2,2),
        ('mesa_cozinha',4,4,2,2),('cadeira_madeira',6,4,1,1),('ventilador',7,4,1,1),('filtro_barro',8,4,1,1),('espada_sao_jorge',9,4,1,1),('samambaia',10,4,1,1),
        ('tapete_croche',0,6,3,2),('rack',3,6,2,1),('estante',5,6,2,1),('capacho',7,6,2,1),('armario_cozinha',9,6,3,1),('pia_banheiro',12,6,1,1),('maquina_lavar',13,6,1,1),('tapete_banheiro',14,6,1,1),('balde',15,6,1,1)]
    flat={'tapete_croche','capacho','tapete_banheiro','box_chuveiro'}
    for name,x,y,w,h in props:
        im=furniture(name,w*T,h*T)
        b=im.getbbox();collision=[] if name in flat else [[b[0],b[1],b[2]-b[0],b[3]-b[1]]]
        register('moveis',name,(x,y),(w,h),im,collision,layer='Detalhes' if name in flat else 'Objetos')
    garden=[
        ('casinha_cachorro',0,0,2,2),('potes',2,0,1,1),('tanque',3,0,2,1),('varal',5,0,4,2),('mangueira',9,0,2,2),('cadeira_plastica',11,0,1,1),('caixa_agua',12,0,2,2),('tijolos_empilhados',14,0,2,1),
        ('canteiro',0,2,3,1),('bananeira',3,2,2,2),('saco_lixo',5,2,1,1),('lixeira',6,2,1,1),('poste',7,2,1,2),('poca',8,2,3,1),('bueiro',11,2,2,1),('tampa_bueiro',13,2,1,1),
        ('portao_fechado',0,4,3,1),('portao_aberto',3,4,1,3),('fios',4,4,4,1),('rachadura_grande',8,4,2,2),('rachadura_pequena',10,4,1,1),('papeis',11,4,1,1),('folhas',12,4,1,1),('pedrinhas',13,4,1,1),('mato',14,4,1,1),('mancha',15,4,1,1),
        ('meio_fio_cima',0,7,1,1),('meio_fio_baixo',1,7,1,1),('meio_fio_esquerda',2,7,1,1),('meio_fio_direita',3,7,1,1),('degraus',4,7,2,1),('telhado_zinco',6,7,2,2)]
    flat={'potes','varal','mangueira','poca','bueiro','tampa_bueiro','fios','rachadura_grande','rachadura_pequena','papeis','folhas','pedrinhas','mato','mancha','degraus','telhado_zinco'}
    for name,x,y,w,h in garden:
        im=exterior(name,w*T,h*T);b=im.getbbox()
        collision=[] if name in flat or name.startswith('meio_fio') else [[b[0],b[1],b[2]-b[0],b[3]-b[1]]]
        if name=='poste':collision=[[9,4,15,16]]
        register('quintal_rua',name,(x,y),(w,h),im,collision,layer='Detalhes' if not collision else 'Objetos')
    for name,im in ATLAS.items():im.save(OUT/(name+'.png'))
    (OUT/'catalogo.json').write_text(json.dumps({'tile_size':T,'sources':list(ATLAS),'tiles':RECORDS},ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'paleta.gpl').write_text('GIMP Palette\nName: Suburbio carioca\nColumns: 8\n#\n'+'\n'.join(f'{C[k][0]:3} {C[k][1]:3} {C[k][2]:3} {k}' for k in P)+'\n',encoding='utf-8')
    preview()
    print(f'{len(RECORDS)} pecas / {len(ATLAS)} atlas exportados em {OUT}')

def preview():
    # Apenas catálogo de edição, nunca consumido pelo mapa.
    im=Image.new('RGB',(1152,1480),'#172822');d=ImageDraw.Draw(im)
    font_path=Path('C:/Windows/Fonts/consola.ttf')
    font=ImageFont.truetype(str(font_path),18) if font_path.exists() else ImageFont.load_default()
    title=ImageFont.truetype(str(font_path),26) if font_path.exists() else font
    d.text((34,24),'SUBURBIO / CENARIO',font=title,fill=P['cream2'])
    d.text((34,64),'32 x 32 px  |  vista de cima  |  PNG + TileSet Godot',font=font,fill=P['mint2'])
    blocks=[('pisos',32,134,'01 / PISOS - 48 variacoes'),('paredes',592,134,'02 / PAREDES - encaixes + aberturas'),('moveis',32,748,'03 / CASA - moveis e decoracao'),('quintal_rua',32,1070,'04 / QUINTAL E RUA')]
    for name,x,y,label in blocks:
        d.text((x,y-32),label,font=font,fill=P['cream2'])
        source=ATLAS[name];scale=2 if name in ['pisos','paredes'] else 1
        if scale==2:source=source.resize((source.width*2,source.height*2),Image.Resampling.NEAREST)
        bg=Image.new('RGBA',source.size);g=ImageDraw.Draw(bg)
        for yy in range(0,bg.height,16):
            for xx in range(0,bg.width,16):g.rectangle((xx,yy,xx+15,yy+15),fill='#273a32' if (xx//16+yy//16)%2 else '#2c4037')
        bg.alpha_composite(source);im.paste(bg.convert('RGB'),(x,y))
        # À direita, ampliação dos props sem interpolação.
        if name in ['moveis','quintal_rua']:
            sample=source.crop((0,0,256,96)).resize((512,192),Image.Resampling.NEAREST)
            bg2=Image.new('RGBA',sample.size,'#273a32');bg2.alpha_composite(sample)
            im.paste(bg2.convert('RGB'),(592,y))
            d.text((592,y+203),'Detalhe em 2x / pixels inteiros',font=font,fill=P['mint2'])
    d.text((34,1430),'Sem personagens. Sem sombras longas embutidas nas paredes.',font=font,fill=P['mint2'])
    im.save(OUT/'previa_tileset.png')

if __name__=='__main__':build()
