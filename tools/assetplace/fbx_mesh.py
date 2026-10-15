"""Minimal binary-FBX reader (Pillow-era tooling, no Blender): meshes with UVs and node translations."""
import struct, zlib
def parse(path):
    d=open(path,'rb').read()
    ver=struct.unpack('<I',d[23:27])[0]
    big=ver>=7500
    pos=27
    def node(pos):
        if big: end,np_,pl,nl=struct.unpack('<QQQB',d[pos:pos+25]);h=25
        else: end,np_,pl,nl=struct.unpack('<IIIB',d[pos:pos+13]);h=13
        if end==0: return None,pos+h
        name=d[pos+h:pos+h+nl].decode();p=pos+h+nl
        props=[]
        for _ in range(np_):
            t=chr(d[p]);p+=1
            if t in 'YCFDLIB':
                f={'Y':'<h','C':'<?','F':'<f','D':'<d','L':'<q','I':'<i','B':'<b'}[t];v=struct.unpack_from(f,d,p)[0];p+=struct.calcsize(f)
            elif t in 'fdlib':
                n,enc,cl=struct.unpack_from('<III',d,p);p+=12
                raw=d[p:p+cl];p+=cl
                if enc:raw=zlib.decompress(raw)
                f={'f':'f','d':'d','l':'q','i':'i','b':'b'}[t];v=list(struct.unpack('<%d%s'%(n,f),raw))
            elif t in 'SR':
                n=struct.unpack_from('<I',d,p)[0];p+=4;v=d[p:p+n];p+=n
                if t=='S':v=v.decode('latin1')
            props.append(v)
        kids=[]
        while p<end:
            k,p=node(p)
            if k is None:break
            kids.append(k)
        return (name,props,kids),end
    out=[]
    while pos<len(d)-40:
        n,pos=node(pos)
        if n is None:break
        out.append(n)
    return out

def meshes(path):
    """{model name: {"T": translation (cm), "V": vertices, "tris": [(vi,vi,vi)], "uvs": per-triangle [(u,v)]*3}}
    for every Geometry linked to a Model (binary FBX, Blender export of the AST-053 kit)."""
    top = {n[0]: n for n in parse(path)}
    models, geoms_ = {}, {}
    for n in top["Objects"][2]:
        if n[0] == "Model":
            pr = [k for k in n[2] if k[0] == "Properties70"][0]
            d = {p[1][0]: p[1][4:] for p in pr[2]}
            models[n[1][0]] = (n[1][1].split("\x00")[0], d.get("Lcl Translation", [0, 0, 0]))
        elif n[0] == "Geometry":
            g = {k[0]: k for k in n[2]}
            V = g["Vertices"][1][0]
            idx = g["PolygonVertexIndex"][1][0]
            lu = [k for k in n[2] if k[0] == "LayerElementUV"][0]
            lg = {k[0]: k[1][0] for k in lu[2]}
            uv, ui = lg["UV"], lg.get("UVIndex")
            tris, uvs, cur = [], [], []
            for i, v in enumerate(idx):
                u = ui[i] if ui else i
                cur.append((v if v >= 0 else -v - 1, (uv[2 * u], uv[2 * u + 1])))
                if v < 0:
                    for k in range(1, len(cur) - 1):
                        tri = (cur[0], cur[k], cur[k + 1])
                        tris.append(tuple(t[0] for t in tri))
                        uvs.append([t[1] for t in tri])
                    cur = []
            geoms_[n[1][0]] = {"V": V, "tris": tris, "uvs": uvs}
    out = {}
    for c in top["Connections"][2]:
        if c[0] == "C" and c[1][0] == "OO" and c[1][1] in geoms_ and c[1][2] in models:
            name, t = models[c[1][2]]
            out[name] = dict(geoms_[c[1][1]], T=t)
    return out
