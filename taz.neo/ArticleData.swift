extension NavController {
func setupArticles() {
articles = []
sectionFiles = ["seite1.html", "dossier.datenschutz.html", "inland.html", "wirtschaft.umwelt.html", "ausland.html", "meinung.diskussion.html", "taz.zwei.html", "kultur.html", "medien.html", "wissenschaft.html", "leibesuebungen.html", "wahrheit.html", "berlin.html", "nord.html", "art00045088.html"]
section2articles["seite1.html"] = ["dossier.datenschutz.html", "art00045170.html", "art00045142.html", "art00045143.html", "art00045147.html", "art00045147.html", "art00045096.html", "art00045150.html", "art00045134.html", "art00045116.html", "art00045097.html", "art00045144.html"]
articles.append(contentsOf: ["dossier.datenschutz.html", "art00045170.html", "art00045142.html", "art00045143.html", "art00045147.html", "art00045147.html", "art00045096.html", "art00045150.html", "art00045134.html", "art00045116.html", "art00045097.html", "art00045144.html"])
section2indices["seite1.html"] = (0, 11)
article2section["dossier.datenschutz.html"] = "seite1.html"
article2section["art00045170.html"] = "seite1.html"
article2section["art00045142.html"] = "seite1.html"
article2section["art00045143.html"] = "seite1.html"
article2section["art00045147.html"] = "seite1.html"
article2section["art00045147.html"] = "seite1.html"
article2section["art00045096.html"] = "seite1.html"
article2section["art00045150.html"] = "seite1.html"
article2section["art00045134.html"] = "seite1.html"
article2section["art00045116.html"] = "seite1.html"
article2section["art00045097.html"] = "seite1.html"
article2section["art00045144.html"] = "seite1.html"
section2articles["dossier.datenschutz.html"] = ["art00045120.html", "art00045121.html", "art00045122.html", "art00045119.html", "art00045117.html", "art00045118.html", "art00045125.html", "art00045126.html"]
articles.append(contentsOf: ["art00045120.html", "art00045121.html", "art00045122.html", "art00045119.html", "art00045117.html", "art00045118.html", "art00045125.html", "art00045126.html"])
section2indices["dossier.datenschutz.html"] = (12, 19)
article2section["art00045120.html"] = "dossier.datenschutz.html"
article2section["art00045121.html"] = "dossier.datenschutz.html"
article2section["art00045122.html"] = "dossier.datenschutz.html"
article2section["art00045119.html"] = "dossier.datenschutz.html"
article2section["art00045117.html"] = "dossier.datenschutz.html"
article2section["art00045118.html"] = "dossier.datenschutz.html"
article2section["art00045125.html"] = "dossier.datenschutz.html"
article2section["art00045126.html"] = "dossier.datenschutz.html"
section2articles["inland.html"] = ["art00045128.html", "art00045127.html", "art00045130.html"]
articles.append(contentsOf: ["art00045128.html", "art00045127.html", "art00045130.html"])
section2indices["inland.html"] = (20, 22)
article2section["art00045128.html"] = "inland.html"
article2section["art00045127.html"] = "inland.html"
article2section["art00045130.html"] = "inland.html"
section2articles["wirtschaft.umwelt.html"] = ["art00045150.html", "art00045151.html", "art00045154.html", "art00045152.html"]
articles.append(contentsOf: ["art00045150.html", "art00045151.html", "art00045154.html", "art00045152.html"])
section2indices["wirtschaft.umwelt.html"] = (23, 26)
article2section["art00045150.html"] = "wirtschaft.umwelt.html"
article2section["art00045151.html"] = "wirtschaft.umwelt.html"
article2section["art00045154.html"] = "wirtschaft.umwelt.html"
article2section["art00045152.html"] = "wirtschaft.umwelt.html"
section2articles["ausland.html"] = ["art00045148.html", "art00045149.html", "art00045134.html", "art00045135.html", "art00045131.html", "art00045133.html", "art00045132.html"]
articles.append(contentsOf: ["art00045148.html", "art00045149.html", "art00045134.html", "art00045135.html", "art00045131.html", "art00045133.html", "art00045132.html"])
section2indices["ausland.html"] = (27, 33)
article2section["art00045148.html"] = "ausland.html"
article2section["art00045149.html"] = "ausland.html"
article2section["art00045134.html"] = "ausland.html"
article2section["art00045135.html"] = "ausland.html"
article2section["art00045131.html"] = "ausland.html"
article2section["art00045133.html"] = "ausland.html"
article2section["art00045132.html"] = "ausland.html"
section2articles["meinung.diskussion.html"] = ["art00045112.html", "art00045114.html", "art00045115.html", "art00045116.html"]
articles.append(contentsOf: ["art00045112.html", "art00045114.html", "art00045115.html", "art00045116.html"])
section2indices["meinung.diskussion.html"] = (34, 37)
article2section["art00045112.html"] = "meinung.diskussion.html"
article2section["art00045114.html"] = "meinung.diskussion.html"
article2section["art00045115.html"] = "meinung.diskussion.html"
article2section["art00045116.html"] = "meinung.diskussion.html"
section2articles["taz.zwei.html"] = ["art00045096.html", "art00045156.html", "art00045155.html", "art00045081.html"]
articles.append(contentsOf: ["art00045096.html", "art00045156.html", "art00045155.html", "art00045081.html"])
section2indices["taz.zwei.html"] = (38, 41)
article2section["art00045096.html"] = "taz.zwei.html"
article2section["art00045156.html"] = "taz.zwei.html"
article2section["art00045155.html"] = "taz.zwei.html"
article2section["art00045081.html"] = "taz.zwei.html"
section2articles["kultur.html"] = ["art00045104.html", "art00045108.html", "art00045106.html", "art00045103.html"]
articles.append(contentsOf: ["art00045104.html", "art00045108.html", "art00045106.html", "art00045103.html"])
section2indices["kultur.html"] = (42, 45)
article2section["art00045104.html"] = "kultur.html"
article2section["art00045108.html"] = "kultur.html"
article2section["art00045106.html"] = "kultur.html"
article2section["art00045103.html"] = "kultur.html"
section2articles["medien.html"] = ["art00045110.html", "art00045130.html", "art00045111.html"]
articles.append(contentsOf: ["art00045110.html", "art00045130.html", "art00045111.html"])
section2indices["medien.html"] = (46, 48)
article2section["art00045110.html"] = "medien.html"
article2section["art00045130.html"] = "medien.html"
article2section["art00045111.html"] = "medien.html"
section2articles["wissenschaft.html"] = ["art00045101.html", "art00045102.html"]
articles.append(contentsOf: ["art00045101.html", "art00045102.html"])
section2indices["wissenschaft.html"] = (49, 50)
article2section["art00045101.html"] = "wissenschaft.html"
article2section["art00045102.html"] = "wissenschaft.html"
section2articles["leibesuebungen.html"] = ["art00045099.html", "art00045098.html", "art00045100.html"]
articles.append(contentsOf: ["art00045099.html", "art00045098.html", "art00045100.html"])
section2indices["leibesuebungen.html"] = (51, 53)
article2section["art00045099.html"] = "leibesuebungen.html"
article2section["art00045098.html"] = "leibesuebungen.html"
article2section["art00045100.html"] = "leibesuebungen.html"
section2articles["wahrheit.html"] = ["art00045084.html", "art00045086.html", "art00045085.html", "art00045090.html", "art00045089.html", "art00045087.html"]
articles.append(contentsOf: ["art00045084.html", "art00045086.html", "art00045085.html", "art00045090.html", "art00045089.html", "art00045087.html"])
section2indices["wahrheit.html"] = (54, 59)
article2section["art00045084.html"] = "wahrheit.html"
article2section["art00045086.html"] = "wahrheit.html"
article2section["art00045085.html"] = "wahrheit.html"
article2section["art00045090.html"] = "wahrheit.html"
article2section["art00045089.html"] = "wahrheit.html"
article2section["art00045087.html"] = "wahrheit.html"
section2articles["berlin.html"] = ["art00045140.html", "art00045139.html", "art00045097.html", "art00045175.html", "art00045174.html", "art00045163.html", "art00045091.html", "art00045093.html", "art00045092.html", "art00045094.html", "art00045095.html", "art00045083.html", "art00045082.html"]
articles.append(contentsOf: ["art00045140.html", "art00045139.html", "art00045097.html", "art00045175.html", "art00045174.html", "art00045163.html", "art00045091.html", "art00045093.html", "art00045092.html", "art00045094.html", "art00045095.html", "art00045083.html", "art00045082.html"])
section2indices["berlin.html"] = (60, 72)
article2section["art00045140.html"] = "berlin.html"
article2section["art00045139.html"] = "berlin.html"
article2section["art00045097.html"] = "berlin.html"
article2section["art00045175.html"] = "berlin.html"
article2section["art00045174.html"] = "berlin.html"
article2section["art00045163.html"] = "berlin.html"
article2section["art00045091.html"] = "berlin.html"
article2section["art00045093.html"] = "berlin.html"
article2section["art00045092.html"] = "berlin.html"
article2section["art00045094.html"] = "berlin.html"
article2section["art00045095.html"] = "berlin.html"
article2section["art00045083.html"] = "berlin.html"
article2section["art00045082.html"] = "berlin.html"
section2articles["nord.html"] = ["art00045138.html", "art00045136.html", "art00045137.html", "art00045171.html", "art00045173.html", "art00045172.html", "art00045123.html", "art00045124.html", "art00045178.html", "art00045179.html", "art00045177.html", "art00045172.html", "art00045160.html", "art00045158.html", "art00045162.html", "art00045161.html", "art00045157.html"]
articles.append(contentsOf: ["art00045138.html", "art00045136.html", "art00045137.html", "art00045171.html", "art00045173.html", "art00045172.html", "art00045123.html", "art00045124.html", "art00045178.html", "art00045179.html", "art00045177.html", "art00045172.html", "art00045160.html", "art00045158.html", "art00045162.html", "art00045161.html", "art00045157.html"])
section2indices["nord.html"] = (73, 89)
article2section["art00045138.html"] = "nord.html"
article2section["art00045136.html"] = "nord.html"
article2section["art00045137.html"] = "nord.html"
article2section["art00045171.html"] = "nord.html"
article2section["art00045173.html"] = "nord.html"
article2section["art00045172.html"] = "nord.html"
article2section["art00045123.html"] = "nord.html"
article2section["art00045124.html"] = "nord.html"
article2section["art00045178.html"] = "nord.html"
article2section["art00045179.html"] = "nord.html"
article2section["art00045177.html"] = "nord.html"
article2section["art00045172.html"] = "nord.html"
article2section["art00045160.html"] = "nord.html"
article2section["art00045158.html"] = "nord.html"
article2section["art00045162.html"] = "nord.html"
article2section["art00045161.html"] = "nord.html"
article2section["art00045157.html"] = "nord.html"
section2articles["art00045088.html"] = []
articles.append(contentsOf: [])
section2indices["art00045088.html"] = (90, 89)
}
}
