#!/usr/bin/env ruby

# Solo per debug salvataggio messaggi su disco
require 'forgery'

# Importo il modulo RabbitMQConfig
require_relative 'rabbitmq_config'

# Importo il modulo per garantire la resilienza dei messaggi in caso di riavvio producer
require_relative 'unsent_message_handler'

# Inizializzo il gestore dei messaggi non inviati
UnsentMessageHandler.init

# Apro una connessione con RabbitMQ usando le configurazioni importate
connection = RabbitMQConfig.connect

# Creo un nuovo canale RabbitMQ sulla connessione esistente
channel    = RabbitMQConfig.create_channel(connection)

# Creo una nuova coda RabbitMQ sul canale esistente
queue      = RabbitMQConfig.create_queue(channel)

###### TEST salvataggio messaggi su disco senza invio #####
# Genero messaggi casuali e li salvo su disco per simulare un precedente shutdown imprevisto del producer
# Questo mi torna utile anche per verificare che i test automatici funzionino correttametne
10.times do
  UnsentMessageHandler.save_message(Forgery(:lorem_ipsum).words(100))
end

# Creo un loop infinito per la pubblicazione manuale di messaggi
# è generalmente considerato una cattiva pratica ma in questo caso si sposa perfettamente per verificare facilmente il
# funzionamento del software e renderlo manuale
loop do

  # Coda in memoria per tentare il reinvio dei possibili messaggi in attesa, un po' paranoica come cosa
  # ma non conoscendo il contenuto e l'importanza dei messaggi preferisco prevenire che curare
  # TODO migliorabile evitando di ricaricare ogni volta tutti i messaggi da disco e magari inserirli in un unico file
  unsent_messages = UnsentMessageHandler.load_unsent_messages

  if unsent_messages.any?
    # Elaboro i messaggi rimasti in sospeso
    puts " [*] Attendi, ci sono dei messaggi non ancora inviati:"
    message_info  = unsent_messages.first
    message       = message_info[:message]
    file_path     = message_info[:file_path]
  else
    puts " [*] Inserisci un nuovo messaggio (digita 'exit' per uscire):"
    message = gets.chomp  # Acquisisco il messaggio dall'input utente

    # Esco dal ciclo se l'utente digita "exit"
    break if message == 'exit'

    # Aggiungi il messaggio alla coda degli invii non completati e lo salvo su disco, ottengo la file_path per cancellarlo una volta
    # inviato al broker
    file_path = UnsentMessageHandler.save_message(message)
  end

  # Pubblico il messaggio sulla coda RabbitMQ
  # routing_key è il nome della coda usato per instradare il messaggio
  # persistent=true salva il messaggio su disco, rendendo il messaggio persistente in modo che sopravviva al riavvio di rabbitMQ e assicurando
  #                 che venga consegnato almeno una volta a un consumer
  channel.default_exchange.publish(message, routing_key: queue.name, persistent: true)

  # Attengo la conferma di ricezione dal broker RabbitMQ
  # Se non si riceve una conferma, sollevo un'eccezione, in un'evolutiva futura sarà possibile impostare dei messaggi di errore
  # compatibili con la struttura sistemistica
  AppLogger.logger.error("!KO! Il broker non è in grado di confermare il messaggio!")
  raise " !KO! Il broker non è in grado di confermare il messaggio!" unless channel.wait_for_confirms

  # Qualora fosse una messaggio in attesa di essere inviato lo rimuovo dalla coda su disco
  UnsentMessageHandler.delete_unsent_message(file_path)

  # Stampa un messaggio di conferma una volta che il messaggio è stato inviato correttamente
  puts " [OK] Inviato #{message}"
  puts "-"*3
end

# Chiude la connessione a RabbitMQ
connection.close

# N.B. sarebbe bene settare un watchdog a livello di server per controllare che il producer sia sempre attivo
