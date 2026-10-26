Dzisiaj porozmawiamy o rootkitach, czyli o jednym z ciekawszych sposobów ukrywania aktywności w systemie operacyjnym.

Sama nazwa pochodzi od słowa „root”, czyli administratora w systemach Unix i Linux. Ale wbrew pozorom rootkit nie musi służyć do zdobywania uprawnień administratora. Jego głównym zadaniem jest ukrywanie tego, co dzieje się w systemie.

Wyobraźmy sobie, że atakujący przejął już kontrolę nad maszyną i uruchomił na niej złośliwy proces. Normalnie moglibyśmy go zobaczyć na liście procesów, sprawdzić jego pliki czy połączenia sieciowe. Rootkit może sprawić, że część tych informacji po prostu przestanie być dla nas widoczna.

Co ważne, ten proces nadal działa. Nie został usunięty ani zatrzymany. Po prostu system może nam pokazywać niepełny obraz rzeczywistości.

I właśnie na tym skupimy się dzisiaj. Nie na tym, jak atakujący dostał się do systemu, ale na tym, co dzieje się później, kiedy rootkit już działa, i jak wykryć coś, co celowo próbuje się przed nami ukryć.


Zacznijmy od tego, jak Linux uruchamia programy i jak oddziela je od jądra systemu.

Mamy tutaj dwa światy: user space, czyli miejsce, w którym działają nasze aplikacje, oraz kernel space, gdzie działa jądro systemu.

Oczywiście nie oznacza to, że mamy dwa osobne procesory czy dwie fizyczne pamięci. To podział logiczny, który jest egzekwowany przez sam procesor.

Każdy proces ma zazwyczaj własną, odizolowaną przestrzeń adresową. Nie może sobie po prostu zajrzeć do pamięci innego procesu, a tym bardziej do pamięci jądra.

Co ciekawe, nawet jeśli uruchomimy program jako root, nadal działa on w user space. Root ma znacznie większe uprawnienia, ale nie oznacza to, że jego kod wykonuje się w trybie jądra.

To jądro kontroluje dostęp do zasobów i decyduje, na jakie operacje może sobie pozwolić dany proces.

No dobrze, ale skoro aplikacja nie ma bezpośredniego dostępu do zasobów systemowych, to jak właściwie prosi jądro o wykonanie jakiejś operacji?

I tutaj dochodzimy do wywołań systemowych, czyli syscalls.





