# Film2WebM
Filme in ein HTML5-kompatibles WebM-Format umrechnen, welches von den meisten aktuellen Internet-Browsern inline abgespielt werden kann. Wie zum Beispiel mit dem FireFox ab Version 125.

Zusätzlich ist es auch möglich im selben "Arbeitsgang" noch Werbung und die schwarzen Balken an den Seiten zu entfernen sowie das Seitenverhältnis zu ändern und die Auflösung auf einen gewünschten Wert zu setzen.

Es handelt sich um eine monolitische und verkürzte Variante des "Filmwandlers Version 7.8.3", mit dem sich nur noch WebM-Dateien erzeugen lassen, in denen die Video-Daten kompatibel zum HTML5-Standard sowie dem von Google im Internet etwablierten Standard sind.

Um die Werbung zu entfernen, muss man den genauen Zeitpunkt kennen, zu dem die Werbung beginnt und endet. Wenn der Film beispielsweise 333 Sekunden lang ist und z.B. nach 12,5 Sekunden Werbung beginnt und nach 33,2 Sekunden die Werbung wieder zu Ende ist (das kann man mit dem "mplayer" sehr gut ermitteln), dann muss man das mit folgendem Parameter angeben:

    
    -schnitt "0-12.5 33.2-333"

Zu beachten ist, dass immer die Zeitspanne angegeben werden muss, die den sehenswerten Teil enthält also darf die Werbung in den angegebenen Zeitspannen nicht enthalten sein!

Untertitelspuren sind hier ein Problem, weil der Container "WebM" nur wenige Untertitelformate im Text-Format versteht.
Sollten in dem zu bearbeitenden Film Untertitelformate im grafischen Format vorliegen (wie z.B. in DVD- oder BD-Ripps) dann ist es nicht möglich diese mit in den neuen Film zu übernehmen.
Untertitel werden mit dieser Option komplett abgeschaltet:

    
    -u =0
