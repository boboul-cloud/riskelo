//
//  PlanDuMonde.swift
//  Riskelo
//
//  Le monde, dessiné.
//
//  Ce fichier ne contient qu'une chose : une grille de cent vingt cases sur
//  soixante-sept, où chaque lettre est un territoire et le point la mer. Les
//  côtes viennent de la géographie — longitudes et latitudes relevées, puis
//  posées sur la grille — et les frontières intérieures de la répartition des
//  cases entre les places du continent. Rien d'autre n'est saisi : les
//  voisinages se déduisent du contact, les contours du parcours des bords, et
//  les traits de frontière du même parcours (voir `Atlas`).
//
//  Trois libertés sont prises avec la géographie, et toutes pour la même
//  raison — à cette taille une cellule vaut trois degrés de longitude, et un
//  détroit large de quinze kilomètres n'existe tout simplement pas :
//
//      Gibraltar, la Manche, le détroit de Davis, la mer du Japon, le canal
//      du Mozambique et le détroit de Torrès sont élargis. Sans quoi
//      l'Afrique tiendrait à l'Europe par la terre, et le Groenland au Canada.
//
//      Les petites îles sont grossies : l'Islande, la Grande-Bretagne, le
//      Japon, Madagascar. Une place du jeu doit porter son nom et sa garnison.
//
//      L'Indonésie tient ses quatre îles rapprochées. C'est la seule place du
//      plateau faite de plusieurs morceaux, et le contour en rend quatre.
//
//  Les quarante-deux territoires et les six terres sont ceux du jeu de
//  conquête classique. Les quatre-vingt-deux voisinages le sont aussi, à un
//  près : le Kamtchatka ne touche pas la Mongolie, et rien dans la géographie
//  ne permet de le lui faire toucher. Vingt d'entre eux sont des traversées —
//  la mer, franchie —, déclarées plus bas et tracées à l'écran.
//

import Foundation

extension Boards {

    /// Le plan du monde, ligne à ligne. Le point est la mer.
    static let planDuMonde: [String] = [
        "......................................................................................................................",
        "..........................................CCCCCCC.....................................................................",
        "......................................CCCCCCCCCCCC....................................................................",
        "......................................CCCCCCCCCCCC........................................a...........................",
        "...............................B.......CCCCCCCCCCCC..................................aaaaaaabbb.......................",
        ".............................BBB.......CCCCCCCCCCCC..............................aaaaaaaaaaabbbbbbbbbbbb..............",
        ".AAAAA......................BBBB.......CCCCCCCCCCC..............O...............daaaaaaaaaaabbbbbbbbbbbbbbbbb.........",
        ".AAAAAAAAAAAABBBBBBBBBBBBBBBBBBB......CCCCCCCCCCCC............OOOOO...........dddaaaaaaaaaaabbbbbbbbbbbbbbbbbccccc....",
        ".AAAAAAAAAAAABBBBBBBBBBBBBBBBBBE......CCCCCCCCCCCNNNNN.......OOOOOO....RRRRRRRddddaaaaaaaaaabbbbbbbbbbbbbbbbbcccccccc.",
        ".AAAAAAAAAAAABBBBBBBBBBBBBBBBBEE.......CCCCCCCCC..NNNN......OOOOOOOOOOORRRRRRRRdddaaaaaaaaaabbbbbbbbbbbbbbbbcccccccc..",
        ".AAAAAAAAAAAAABBBBBBBBBBBBBBBEEE.......CCCCCCC....NNNN.....OOOOOOO..ORRRRRRRRRRdddaaaaaaaaaeebbbbbbbbbbbbbcccccccccc..",
        "..AAAAAAAAAAAABBBBBBBDDDBBBEEEEE........CCCCC.............OOOOOOO..RRRRRRRRRRRddddaaaaaaaaaeeebbebbbbbbbbcccccccccc...",
        "..AAAAAAAAAAADDDDDDBDDDDDBEEEEEE...F....CCCC..........PPP.OOOOOOO.RRRRRRRRRRRRddddaaaaaaaaeeeeeeeebbbcccccccccccccc...",
        "...AAA.....ADDDDDDDDDDDDDDEEEEEE.FFFF.................PPP.OOOOO..QRRRRRRRRRRRRdddaaaaaaaaeeeeeeeeeeecccccccccccc......",
        "...A........DDDDDDDDDDDDDEEEEEEEEFFFF................PPPPPOOOO..QQRRRRRRRRRRRdddaaaaaaaaeeeeeeeeeeeeccccccccccc.......",
        ".............DDDDDDDDDDDEEEEEEEEFFFFFF...............PPPP.QQQQQQQQRRRRRRRRRRRddddaaaaaaaaeeeeeeeeeeeecccccccccc.......",
        "..............DDDDDDDDGEEEEEEEEFFFFFFFF...................QQQQQQQRRRRRRRRRRRddddddaaaaaaaaeeeeeeeeeeeecccccccc........",
        "..............DDDDDDDGGGEEEEEEFFFFFFFF....................SQQQQQQRRRRRRRRRRddddddddaaaaaaaffeeffeeeee.ccccccc.........",
        "...............DDDDDGGGGGEEEEHHFFFFFFF..................SSSSQTTQTTRRRRRRRRhhhdddddddaaaaaaffffffffee....ccccc.........",
        "...............DDDDGGGGGGGEEHHHHFFFF....................SSSSTTTTTTTRRRRRRRhhhhdddddddaaaaffffffffffe....ggcc..........",
        "...............GGGGGGGGGGGEHHHHHHFF...................SSSSSS.TTTTTT...j....hhhhhhddddaaaaffffffffff.....ggg...........",
        "...............GGGGGGGGGGGHHHHHHHH....................SSSS...TTTTTT..jjjj...hhhhhhddiiiiiffffffffff.....ggg...........",
        "...............GGGGGGGGGGHHHHHHHH.....................SSSS....TT.....jjjj...hhhhhhhhiiiiiifffffffff....ggg............",
        "................GGGGGGGGHHHHHHHH....................................jjjjjj...hhhhhhhiiiiiiiiiiffiii....ggg............",
        ".................GGGGGGGHHHHHHHH....................................jjjjjj...hhhhhhhiiiiiiiiiiiiii....ggg.............",
        "...................GGGGGHHHHHHHH.......................UUUUUUUU.......jjjj...hhhhhhhiiiiiiiiiiiiii....ggg.............",
        "...................GGGGIIHHHHHH.......................UUUUUUUUUUUUVVj.jjjj...jjjkkkkiiiiiiiiiiiiii..ggg...............",
        "....................GGIIIIHH.HH......................UUUUUUUUUUUUUVVjjjjjj...jjkkkkkiiiiiiiiiiiii....g................",
        "....................GIIII.....H......................UUUUUUUUUUUUVVVVjjjjjj..jkkkkkkkiiiiiiiiiiii.....................",
        "....................IIIII.....H.....................UUUUUUUUUUUUVVVVVjjjjjjjjjkkkkkkkkiiilliiiii......................",
        ".....................IIII...........................UUUUUUUUUUUVVVVVVVjjjjjj...kkkkkkkklllllllii......................",
        "......................III..I.......................UUUUUUUUUUUUUVVVVVVjjjjjj....kkkkkk.lllllll........................",
        ".......................II.III......................UUUUUUUUUUUUUVVVVVVVjjjj.....kkkkk...lllll.........................",
        "........................IIIIII.....................UUUUUUUUUUUUUVVVXXXXjjjj......kkkk...lllll.........................",
        "..........................IIIII....................UUUUUUUUUUUUUVVXXXXXXjj.......kkk....llll..........................",
        "............................III..J.................UUUUUUUUUUUUXXXXXXXXXXXX.......kk.....lll..........................",
        ".............................IIIJJJJJ...............UUUUUUUUUUXXXXXXXXXXXXX.......k......lll..........................",
        ".............................IIIJJJJJJ..............UUUUUUUUUWWWXXXXXXXXXX........k...................................",
        "...............................JJJJJJJJ..............UUUUUWWWWWWWXXXXXXXX...............mmm...........................",
        "...............................JJJJJJJJJ.............UUWWWWWWWWWWWXXXXXXX...............mm......m.....................",
        "...............................JJJJJJJJJL.................WWWWWWWWWXXXXX...............mmmm..mmmm.mmn.................",
        "..............................JJJJJJJJJLLL.................WWWWWWWWWXXXX...............mmmmm.mmmmmmmnnnnn.............",
        "..............................JJJJJJJJLLLLL.................WWWWWWWWXXX.................mmmm.mmmmmmmnnnnnn............",
        "..............................JJKKJJJLLLLLLL................WWWWWWWXXXX.................mmmmmmmmm.mnnnnnnnnn..........",
        "...............................KKKKKLLLLLLLLLL..............WWWWWWWXXXX..................mmmm..m..nnnnnnnnnnn.........",
        "...............................KKKKKLLLLLLLLLL..............WWWWWWWXXXX..................mmmmm........................",
        "................................KKKKLLLLLLLLL................WWWWWWWX.....................mmmmmmm.....................",
        "................................KKKKKLLLLLLLL................WWWWWWWX...Z..................mmmmmm.....................",
        "................................KKKKKKLLLLLLL................WWWWWWWX...ZZZ.....................m.oooopppp............",
        ".................................KKKKKLLLLLL.................WWWWWWYX...ZZZ......................ooooopppp............",
        ".................................KKKKKLLLLLL.................WWWWWYYY...ZZZ......................oooooppppp...........",
        ".................................KKKKLLLLLL..................YYYYYYYY...ZZ......................ooooopppppp...........",
        ".................................KKKLLLLLLL...................YYYYYYY...ZZ....................ooooooopppppp...........",
        ".................................KKKLLLLLL....................YYYYYYY...ZZ....................oooooooppppppp..........",
        ".................................KKKLLLLL.....................YYYYYYY....Z....................oooooooopppppp..........",
        ".................................MMMMLLLL.....................YYYYYY...........................oooooopppppppp.........",
        ".................................MMMMMLL.......................YYYYY...........................oooooopppppppp.........",
        ".................................MMMMMMM.......................YYYY............................ooooooppppppp..........",
        ".................................MMMMMM........................YYYY............................oo.....pppppp..........",
        ".................................MMMMMM................................................................pppp...........",
        ".................................MMMMM..................................................................ppp...........",
        "................................MMMMM.................................................................................",
        "................................MMMMM.................................................................................",
        "................................MMMM..................................................................................",
        "................................MMMM..................................................................................",
        "................................MMMM..................................................................................",
        "................................MMM...................................................................................",
        "................................MMM...................................................................................",
        "......................................................................................................................",
    ]

    static let terresDuMonde: [Atlas.Terre] = [
        .init("nord", "Amérique du Nord", 5),
        .init("sud", "Amérique du Sud", 2),
        .init("europe", "Europe", 5),
        .init("afrique", "Afrique", 3),
        .init("asie", "Asie", 7),
        .init("oceanie", "Océanie", 2),
    ]

    /// Une lettre par place, dans l'ordre où le plan les nomme.
    static let placesDuMonde: [Atlas.Place] = [
        .init("A", "nord", "Alaska"),
        .init("B", "nord", "Territoires du Nord-Ouest"),
        .init("C", "nord", "Groenland"),
        .init("D", "nord", "Alberta"),
        .init("E", "nord", "Ontario"),
        .init("F", "nord", "Québec"),
        .init("G", "nord", "Ouest des États-Unis"),
        .init("H", "nord", "Est des États-Unis"),
        .init("I", "nord", "Amérique centrale"),
        .init("J", "sud", "Venezuela"),
        .init("K", "sud", "Pérou"),
        .init("L", "sud", "Brésil"),
        .init("M", "sud", "Argentine"),
        .init("N", "europe", "Islande"),
        .init("O", "europe", "Scandinavie"),
        .init("P", "europe", "Grande-Bretagne"),
        .init("Q", "europe", "Europe du Nord"),
        .init("R", "europe", "Ukraine"),
        .init("S", "europe", "Europe de l'Ouest"),
        .init("T", "europe", "Europe du Sud"),
        .init("U", "afrique", "Afrique du Nord"),
        .init("V", "afrique", "Égypte"),
        .init("W", "afrique", "Congo"),
        .init("X", "afrique", "Afrique de l'Est"),
        .init("Y", "afrique", "Afrique du Sud"),
        .init("Z", "afrique", "Madagascar"),
        .init("a", "asie", "Sibérie"),
        .init("b", "asie", "Iakoutie"),
        .init("c", "asie", "Kamtchatka"),
        .init("d", "asie", "Oural"),
        .init("e", "asie", "Irkoutsk"),
        .init("f", "asie", "Mongolie"),
        .init("g", "asie", "Japon"),
        .init("h", "asie", "Afghanistan"),
        .init("i", "asie", "Chine"),
        .init("j", "asie", "Moyen-Orient"),
        .init("k", "asie", "Inde"),
        .init("l", "asie", "Siam"),
        .init("m", "oceanie", "Indonésie"),
        .init("n", "oceanie", "Nouvelle-Guinée"),
        .init("o", "oceanie", "Australie occidentale"),
        .init("p", "oceanie", "Australie orientale"),
    ]

    /// La mer, franchie. Vingt portes, et la carte entière en dépend : sans
    /// elles l'Amérique, l'Europe et l'Océanie seraient trois mondes séparés.
    static let traverseesDuMonde: [(String, String)] = [
        ("Afrique de l'Est", "Madagascar"),
        ("Afrique du Nord", "Brésil"),
        ("Afrique du Nord", "Europe de l'Ouest"),
        ("Afrique du Nord", "Europe du Sud"),
        ("Afrique du Sud", "Madagascar"),
        ("Alaska", "Kamtchatka"),
        ("Australie occidentale", "Indonésie"),
        ("Australie occidentale", "Nouvelle-Guinée"),
        ("Australie orientale", "Nouvelle-Guinée"),
        ("Europe de l'Ouest", "Grande-Bretagne"),
        ("Europe du Nord", "Grande-Bretagne"),
        ("Europe du Sud", "Moyen-Orient"),
        ("Europe du Sud", "Égypte"),
        ("Grande-Bretagne", "Islande"),
        ("Groenland", "Ontario"),
        ("Groenland", "Québec"),
        ("Groenland", "Territoires du Nord-Ouest"),
        ("Indonésie", "Siam"),
        ("Islande", "Scandinavie"),
        ("Japon", "Mongolie"),
    ]
}
