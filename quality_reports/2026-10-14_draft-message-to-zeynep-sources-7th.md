# Draft — richiesta a Zeynep: fonti coding VII legislatura (2026-10-14)

> Nota per Federico: le richieste sono ridotte rispetto a quella prevista questa mattina,
> perché la v2 (`minorities7th_coded_zm.xlsx`) ha già le note (45) e i valori già 0/1,
> con classificazioni identiche alla v1. Mancano solo: i link, la nota per Le Brun e la
> conferma sui 30 casi di dubbio. I 16 positivi e i 30 dubbi con le sue note sono
> estratti in `data/minorities7th_coding_sources.csv`.

---

Subject: 7th term coding — 3 small things before we merge

Hi Zeynep,

Thanks again for the updated 7th-term file — it's merge-ready on our side: same 468 MEPs
and identical classifications as the first version, booleans already 0/1, and the notes
column works very well (we keep them as an audit trail, including your 30 annotations on
non-minority "doubt" cases — very useful for us).

Only 3 small things are left before we lock the coding and merge it into the master:

1. **Sources/links.** The `link` column is empty in all rows. Could you paste the URLs you
   used for the **16 minority=1 MEPs** (short official-biography links are fine)? If easy,
   also for the 30 doubt cases — but that's not urgent.

2. **Agnès Le Brun (parliamentary_id 105849)** is coded minority=1 but has no note. Which
   criterion/basis did her case meet?

3. **The 30 doubt cases** (minority=0 with your notes — e.g. Haglund, Gustafsson,
   Cohn-Bendit, Bisky, Ibrisagic, Dehaene). We will keep them at 0 exactly as you coded
   them; a quick confirmation that these are deliberate under our definition (migrant /
   minority background) would let us close QA, since a few sit right on the boundary
   (national minorities like the Swedish-speaking Finns, foreign-born without a migrant
   background, descendants of refugees).

Thanks a lot!