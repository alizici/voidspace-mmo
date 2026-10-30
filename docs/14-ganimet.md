---
alan: 14
ad: Ganimet
katman: ekonomi
tur: kural
surum: 1.1
tablo: 14-ganimet-tablosu.md
kaynak: https://claude.ai/code/artifact/3c6ed1b7-67c9-47cd-be62-bbea6586700c
---

# 14 · Ganimet

Ne düşer, ne sıklıkla, ve kötü şansın nerede durdurulduğu. Ganimet bir ödül sistemi değil, bir arz sistemi. Alan 13 talebi ilan etti: bir nesilde şu kadar malzeme, şu kadar eşya gerekiyor. 14'ün tek işi o talebi karşılamak, ve karşılarken kimsenin kötü şansa takılmamasını sağlamak.

Kullandığı: [06](06-esya-kurgusu.md) kalite bantları · [12](12-dusman-kurgusu.md) yaratık ödülleri · [13](13-kaynak-akisi.md) gider payları. Kapattığı: 13 → malzeme talebi ≤ arz. Sayı tablosu: [14 · Ganimet Tablosu](14-ganimet-tablosu.md).

Sürüm 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. Parçalama çeviriciyi de veriyor (07.8); bu belgenin 1.0'ında yoktu.

## 14.1 · Üç düşen, üç ritim
Durum: kodda · s1 · GanimetCekilisi.cek

| Düşen | Sıklık | Miktar | Ritmi |
|---|---|---:|---|
| Malzeme | her öldürme | 1 | Sürekli. Oyuncunun her saniye ilerlediğini hissettiren şey. |
| Eşya | türetilen şans | 1 | Nadir ama beklenebilir; on üç dakikada bir. |
| NOVA | her öldürme | 1 | Sabit; 12'nin kuralı, kademeyle ölçeklenmiyor. |

Üç ayrı ritim bilinçli. Sürekli olan sıkılmayı önlüyor, nadir olan heyecanı taşıyor; tek bir ritim olsaydı ya her düşen değersizleşir ya da uzun boşluklar oyunu durdururdu. Kredi bu listede yok çünkü kredi düşmüyor, yaratık ödülü olarak doğrudan geliyor; ganimet ve kredi ayrı musluklar (13). Düşen anında söyleniyor: sunucu imhayla birlikte ne düştüğünü ayrı bir mesajla (ServerGanimet) yolluyor, HUD ödül şeridinde eşyayı rank renginde adıyla, malzemeyi adediyle yazıyor. Hangar durumu envanterin doğrusu, mesaj "ne düştü" sorusunun cevabı; görülmeyen ödül olmayan ödüldür.

## 14.2 · Malzeme kuru: bir öldürme, bir malzeme
Durum: kodda · s1 · Ganimet.malzemeDegeriFor, Ganimet.malzemeFor

Bir malzeme kaç kredi eder? Cevabı seçmek yerine türetmek mümkün: bir malzeme ≡ bir öldürme ≡ o bandın yaratık ödülü. Kurun getirisi: malzeme arz/talep oranı bütün bantlarda aynı. Bir bantta bol olan malzeme diğerinde kıt olmuyor, çünkü hem yaratık ödülü hem gelir hedefi aynı α'yı izliyor. Alan 13'ün doğrulayamadan bıraktığı tek değişmez böyle kapandı; tampon çevirme ve israf payı için, sıfıra yaklaşmıyor, ikiye de çıkmıyor.

## 14.3 · Düşme şansı birinci banttan türer
Durum: kodda · s2 · Ganimet.dusmeSansi, Ganimet.droidDusmeSansi

Eşya düşme şansı en dar bandın ihtiyacından türetiliyor, çünkü orada tutarsa her yerde tutar. İhtiyaç: her yuva için en iyi `kaliteHedefi = 0,2` dilimindeki bir roll, yani yuva başına ortalama beş deneme. Şans = (yuva ÷ kalite hedefi) ÷ (nesil süresi × öldürme hızı) × `dusmeGuvenligi = 1,5`. Şansın bütün bantlarda sabit kalması bilinçli: üst bantlarda nesiller uzuyor ama düşme ritmi değişmiyor. Sonuç: üst bantlarda bolluk artıyor; geç oyunda seçme lüksü var, ve o lüks +15'e ulaşamayan oyuncunun elindeki tek derinleşme yolu. Filo yuvaları ayrı kalem: droid eşyasının düşme şansı aynı kuraldan, on yuva için (`droidFiloTavani = 10`), gövde şansına eklenmeden yanında; droid kendi zarını atıyor, boss'ta da aynı oranla. Gövde zarı yalnız gövde yuvalarının tiplerini çeker.

## 14.4 · Rank dağılımı ve PRD yalnız üst rankta
Durum: kodda · s1 · Ganimet.sansFor, Ganimet.ustRankPrdSabiti

Düşen eşyanın rankı üç sonuçlu bir çekiliş: bir alt rank `altRankSansi = 0,2` (hayal kırıklığı değil, parçalanacak malzeme), bandın rankı (normal akış, kalite rolü burada oynanıyor), bir üst rank `ustRankSansi = 0,15` (olay). Üst rank bağımsız zarla bırakılırsa bazı oyuncular onu saatlerce görmez; çözüm sahte rastgele dağılım: her başarısız denemede şans artıyor, başarıda sıfırlanıyor. İlan edilen olasılık sabitin kendisi değil; sabit hedef ortalamadan sayısal çözülüyor ve bir garanti eşiği veriyor. PRD yalnız üst ranka uygulanıyor: diğer ikisi sık gerçekleştiği için kötü seri üretmiyor, ve PRD onları tahmin edilebilir yaparak sıkıcılaştırırdı. Seri kırıcının kırdığı seri, oyuncunun o bantta geçirdiği süreden kısa olmak zorunda.

## 14.5 · Parçalama: eşyanın ikinci hayatı
Durum: kodda · s1 · Ganimet.parcalamaVerimi, GanimetCekilisi.parcalamaKazanci

Bir nesilde düşen eşyaların çoğu takılmıyor; kalanı parçalanıyor. Parçalama malzemeye çeviriyor, krediye değil: krediye çevirseydi ganimet ikinci bir kredi musluğu olur ve 11'in saatlik hedefi anlamını yitirirdi. Oran türetilen: bir eşya ortalama düşme şansının tersi kadar öldürmeye mal oluyor ve parçalama bunun `parcalamaOrani = 0,15` kadarını geri veriyor; tamamını verseydi eşya farmı malzeme farmıyla eşitlenirdi. Parçalama ayrıca bir çevirici veriyor ve çeviricinin tek kaynağı bu (07.8). İki farklı eşyanın iki farklı yolu var: kötü rollü yüksek rank parçalanır, iyi rollü düşük rank sentezlenir.

## 14.6 · Boss ganimeti garantili
Durum: kodda · s1 · Ganimet.bossUstRankSansi, Ganimet.bossKaliteAltSiniri

Boss'un ganimeti şansa bırakılmıyor: her zaman `bossEsyaSayisi = 3` eşya, dağılımı yukarı kaymış (yarısı bandın rankı, yarısı bir üst) ve dar kalite bandı. Üst rank için PRD uygulanmıyor: boss zaten iki saatte bir doğuyor ve grup gerektiriyor, yani kendisi bir seri kırıcı; üstüne PRD koymak nadirliğin iki kez telafi edilmesi olurdu. Güçlü yaratık sıradan olanın beş katını veriyor; canı da beş katı. Ganimet zamanla orantılı, güçlü yaratığa girmenin karşılığı hız değil risk primi.

## Sınır

Sahiplenmediği: kalite bantları → 06 · yaratık ödülleri → 12 · gider payları → 13 · mağazada ne satılır → 15 · sentez oranı → 07. 14 arzı çözüyor, talebi değil; talep 13'ten geliyor ve 14 ona uymak zorunda.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Malzeme arz/talep oranı 1,4 – 2,0 (her bantta) | Artı basmak ganimetle tıkanıyor ya da malzeme değersizleşiyor. |
| Oran bantlar arasında sabit (±%5) | Kur bozulmuş. |
| Eşya bolluğu ≥ 1,0 | Oyuncu yuvalarını dolduramıyor. |
| Düşme aralığı ≤ 15 dakika | Nadir olan can sıkıcı olmuş. |
| PRD garantisi < nesil süresi | Seri kırıcı işlevsiz. |
| Parçalama verimi < eşyanın öldürme maliyeti | Eşya farmı malzeme farmının yerine geçmiş. |
| Güçlü yaratığın ganimeti canıyla orantılı | Bir sınıf ganimet için diğerinden verimli olmuş. |
| Boss ganimeti %100 | İki saat bekleyip grup toplamak boşa çıkabiliyor. |
