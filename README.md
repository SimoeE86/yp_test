# Sistema di Messaggistica - YP_test

Questo progetto implementa un sistema di messaggistica basato su RabbitMQ con un focus sulla persistenza dei dati e la resilienza dei messaggi. Il sistema è composto da tre componenti principali: il producer (`producer.rb`), il broker RabbitMQ configurato tramite il file (`rabbitmq_config.rb`) e il consumer (`consumer.rb`). Per garantire che i messaggi non vengano persi in caso di interruzioni è stato implementato anche un gestore per i messaggi non inviati (`unsent_message_handler.rb`) con salvataggio su disco. Per verificare il funzionamento del sistema è disponibile uno script di test basilare (`system_test.rb`).

## Gestione delle Eccezioni e degli Errori

Le eccezioni e gli errori sono state gestite tramite queste strategie:

- Nel producer e nel consumer, le eccezioni sono catturate e registrate nei log utilizzando il modulo `AppLogger`. Questo permette di tracciare e monitorare gli errori nel sistema.

- Nel caso in cui il broker RabbitMQ non sia disponibile o si verifichi un errore durante la connessione, il sistema termina con un messaggio di errore appropriato.

- Nel consumer, in caso di errore durante il processamento di un messaggio, il messaggio viene rifiutato e spostato nella coda Dead Letter Exchange (DLX), consentendo una gestione manuale dei messaggi problematici in un secondo momento.


## Persistenza dei Dati nel Broker di Messaggi

La persistenza dei dati è garantita tramite le seguenti configurazioni:

- La coda principale è dichiarata con l'opzione `durable: true`, il che significa che i dati della coda vengono salvati su disco. In caso di riavvio del broker, errori e/o crash la coda e i suoi messaggi non verranno persi.

- I messaggi vengono pubblicati con l'opzione `persistent: true`, salvando il messaggio  su disco. Questo assicura che il messaggio sopravviva al riavvio del broker e che venga consegnato almeno una volta a un consumer.

## Garanzia che i Messaggi non vengano Persi

Per garantire che i messaggi non vengano persi, sono state implementate le seguenti strategie:

- Nel producer, i messaggi non inviati vengono salvati su disco utilizzando il modulo `UnsentMessageHandler` prima dell'invio effettivo. Questi messaggi vengono successivamente rimosso da disco solo dopo che siano stati inviati con successo al broker.

- Nel consumer, in caso di errore durante il processamento di un messaggio, quest'ultimo viene rifiutato e spostato nella coda DLX. Questo assicura che i messaggi problematici possano essere gestiti manualmente successivametne e non persi.

- Nel test di sistema (`system_test.rb`), il processo di avvio e spegnimento del broker RabbitMQ, insieme all'esecuzione del producer e del consumer in background, è progettato per simulare un ambiente realistico in cui il sistema può essere interrotto e poi ripreso senza perdere messaggi.

## Esecuzione del Codice

Per eseguire il codice sono necessari questi passaggi:

1. RabbitMQ correttamente installato e in esecuzione (è stata utilizzata la config di default per la connessione guest/guest).

2. Eseguire il producer con il comando `ruby producer.rb` e inserire manualmente il messaggio che si vuole inviare (n.b. per test il producert invierà al broker una decina di messaggi per simulare una ripresa del servizio con messaggi in memoria non consegnati).

4. Avviare il consumer con il comando `ruby consumer.rb`.

5. Il consumer in esecuzione otterrà i messaggi dalla coda e li mostrerà a schermo.

6. Utilizzando il comando `ruby system_test.rb` è possibile avviare un breve e basilare test di invio e ricezione.

## Resilienza dei Messaggi

La resilienza dei messaggi è garantita dalle seguenti caratteristiche:

- Il producer salva i messaggi non inviati su disco prima dell'invio effettivo, garantendo che i messaggi non vengano persi in caso di riavvio imprevisto.

- Il consumer gestisce gli errori inviando i messaggi problematici alla coda DLX anziché eliminarli, consentendo la loro gestione manuale.

- Il test di sistema è configurabile in modo che possa simulare scenari di interruzione e ripresa per verificare che i messaggi non vengano persi.

Questo sistema di messaggistica è stato progettato per essere robusto e garantire che i messaggi siano affidabilmente consegnati e gestiti, anche in presenza di interruzioni o errori.

## Possibili Migliorie future

Il codice è stato commentato esplicando in quali parti è migliorabile, ad ogni modo riporto anche qui degli spunti per aumentare la manutenibilità e la fruibilità futura del progetto:

**Gestione delle Eccezioni**: Migliorare la gestione delle eccezioni specificando maggiori dettagli come il tipo di eccezione, il componente che l'ha sollevata, la timestamp e una migliore descrizione dell'evento.

**Logging**: Espandere il modulo di logging (`AppLogger`) includendo l'invio dei log verso un log server centralizzato includendo il contesto degli errori, timestamp e l'origine dell'errore.

**Sicurezza**: Spostare i dati sensibili, come password, username e dettagli di connessione in variabili d'ambiente.

**Test**: Scrivere test unitari per singola componente del sistema, passare a una soluzione più robusta come `Rspec`.

**Documentazione**: Descrivere nel dettaglio il funzionamente dell'applicativo utilizzando tool
collaborativi come Confluence.

**Riconnessione e Retry**: Come menzionato nei commenti, nel mondo reale e con maggiore cognizione di causa, si potrebbe aggiungere la logica di riconnessione e un meccanismo di retry in caso di errori di connessione o elaborazione dei messaggi.

**Tracciamento delle modifiche**: Introduzione di un changelog per registrare e monitorare le diverse versioni del software.
