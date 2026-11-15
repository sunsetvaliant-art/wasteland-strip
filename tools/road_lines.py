import struct, numpy as np
def read(path):
    f=open(path,'rb').read(); o=0
    def u32():
        nonlocal o; v=struct.unpack_from('<I',f,o)[0]; o+=4; return v
    out=[]
    nt=u32()
    for _ in range(nt):
        tx=u32(); tz=u32(); npc=u32()
        for _ in range(npc):
            hs,sf,mk,wl=struct.unpack_from('<4f',f,o); o+=16
            n=u32(); a=np.frombuffer(f,dtype='<f4',count=n*5,offset=o).reshape(n,5); o+=n*20
            out.append((hs,sf,a[:,:2].copy()))
    return out
def dense(pcs, step=1.0):
    P=[];H=[]
    for hs,sf,a in pcs:
        for p,q in zip(a,a[1:]):
            L=np.hypot(*(q-p)); n=max(1,int(L/step))
            for k in range(n):
                P.append(p+(q-p)*k/n); H.append(hs)
    return np.array(P),np.array(H)
