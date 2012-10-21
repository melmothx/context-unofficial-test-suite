% context --metapost --format=metafun --pdf direct-001.mp

beginfig(1) ;
    fill fullcircle scaled 5cm withcolor red ;
endfig ;

beginfig(2) ;
    fill fullcircle scaled 3cm withcolor blue ;
endfig ;

beginfig(3) ;
    fill fullcircle scaled 6cm withcolor green ;
    draw textext("it seems to work") ;
endfig ;
