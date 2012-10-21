% mtxrun --script metapost mp-001.mp
% mtxrun --script metapost --split mp-001.mp

color c ; c := red;

beginfig(1);
    draw origin withpen pencircle scaled 2mm withcolor green ;
    draw btex $x+1=2$ etex;
    draw boundingbox currentpicture withcolor c ;
endfig;

beginfig(2);
    draw origin withpen pencircle scaled 2mm withcolor green ;
    draw btex $x+2=3$ etex;
    draw boundingbox currentpicture withcolor c ;
endfig;

end.
