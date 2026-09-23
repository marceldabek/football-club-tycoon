"""Dump a binary FBX's axis settings, mesh bounds and model transforms.

P5 (2026-09-23): the kit export centred every piece of a multi-part Poly Haven
model, so drawers and laptop lids lost their positions. This reads the raw
source (assets/kit/_raw/PolyHaven/<name>/*.fbx) to get them back; see
KIT_OFFSETS in src/server/Clubhouse.luau. Geometry is in Blender metres
(Z up; x, y, z -> model x, height, z), studs = metres x 2.75.

Usage: python tools/fbx_dump.py path/to/model.fbx
"""
import struct,zlib,sys
def parse(path):
    b=open(path,'rb').read()
    ver=struct.unpack('<I',b[23:27])[0]
    big=ver>=7500
    def rd_node(o):
        if big: end,nprop,plen=struct.unpack('<QQQ',b[o:o+24]); o+=24
        else: end,nprop,plen=struct.unpack('<III',b[o:o+12]); o+=12
        if end==0: return None,o
        nl=b[o]; o+=1; name=b[o:o+nl].decode('latin1'); o+=nl
        props=[]
        for _ in range(nprop):
            t=chr(b[o]); o+=1
            if t=='Y': props.append(struct.unpack('<h',b[o:o+2])[0]); o+=2
            elif t=='C': props.append(b[o]); o+=1
            elif t=='I': props.append(struct.unpack('<i',b[o:o+4])[0]); o+=4
            elif t=='F': props.append(struct.unpack('<f',b[o:o+4])[0]); o+=4
            elif t=='D': props.append(struct.unpack('<d',b[o:o+8])[0]); o+=8
            elif t=='L': props.append(struct.unpack('<q',b[o:o+8])[0]); o+=8
            elif t in 'fdlib':
                n,enc,cl=struct.unpack('<III',b[o:o+12]); o+=12
                data=b[o:o+cl]; o+=cl
                if enc==1: data=zlib.decompress(data)
                fmt={'f':'f','d':'d','l':'q','i':'i','b':'?'}[t]
                props.append(list(struct.unpack('<%d%s'%(n,fmt),data)))
            elif t in 'SR':
                n=struct.unpack('<I',b[o:o+4])[0]; o+=4; props.append(b[o:o+n]); o+=n
        kids=[]
        while o<end:
            k,o2=rd_node(o)
            o=o2
            if k is None: break
            kids.append(k)
        return (name,props,kids),end
    o=27; nodes=[]
    while o<len(b)-200:
        n,o=rd_node(o)
        if n is None: break
        nodes.append(n)
    return nodes
def find(nodes,name): return [n for n in nodes if n[0]==name]
nodes=parse(sys.argv[1])
gs=find(nodes,'GlobalSettings')
for p in find(gs[0][2],'Properties70')[0][2]:
    k=p[1][0].decode('latin1')
    if 'Axis' in k or 'Unit' in k: print(k,p[1][4:])
objs=find(nodes,'Objects')[0][2]
geo={}
for n in objs:
    if n[0]=='Geometry':
        v=find(n[2],'Vertices')[0][1][0]
        xs,ys,zs=v[0::3],v[1::3],v[2::3]
        geo[n[1][0]]=(n[1][1].split(b'\x00')[0].decode(),[(min(a)+max(a))/2 for a in (xs,ys,zs)],[max(a)-min(a) for a in (xs,ys,zs)])
models={}
for n in objs:
    if n[0]=='Model':
        pr={}
        for p in find(n[2],'Properties70')[0][2]:
            k=p[1][0].decode('latin1')
            if k.startswith('Lcl') or 'PreRotation' in k: pr[k]=[round(x,3) for x in p[1][4:]]
        models[n[1][0]]=(n[1][1].split(b'\x00')[0].decode(),pr)
conns=find(nodes,'Connections')[0][2]
for c in conns:
    a,bb=c[1][1],c[1][2]
    if a in geo and bb in models: print('GEO',geo[a][0],'->',models[bb][0],'geoCentre',[round(x,3) for x in geo[a][1]],'geoSize',[round(x,3) for x in geo[a][2]])
for mid,(nm,pr) in models.items():
    parent=[models[c[1][2]][0] for c in conns if c[1][1]==mid and c[1][2] in models]
    print('MODEL',nm,pr,'parent',parent)
