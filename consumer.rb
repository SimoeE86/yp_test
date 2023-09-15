#!/usr/bin/env ruby

# Importo il modulo RabbitMQConfig
require_relative 'rabbitmq_config'

# Apro una connessione con RabbitMQ usando le configurazioni importate
connection = RabbitMQConfig.connect

# Creo un nuovo canale RabbitMQ sulla connessione esistente
channel    = RabbitMQConfig.create_channel(connection)

# Creo una nuova coda RabbitMQ sul canale esistente
queue      = RabbitMQConfig.create_queue(channel)

# Imposto il numero massimo di messaggi NON confermati che il consumer può ricevere dal broker.
# Il consumer può accettare un solo messaggio alla volta dal broker, solo dopo che il consumer ha processato quel messaggio
# e inviato una conferma, può ricevere un altro messaggio dalla coda
channel.prefetch(1)

puts " [*] In attesa di messaggi.... Per uscire premi CTRL+C / COMMAND+C"

# Inizio del blocco per la gestione dei messaggi ricevuti.

# Sottoscrivo alla coda per ricevere i messaggi
# manual_ack=true il messaggio non viene rimosso dalla coda fino a quando il consumer
#                 non invia conferma al broker
# block=true mantiene il consumer in esecuzione in modo da renderlo sempre disponibile
queue.subscribe(manual_ack: true, block: true) do |delivery_info, _properties, body|
  begin
    # Stampa il corpo del messaggio ricevuto.
    puts " [OK] Ricevuto #{body}"

    # Invia la conferma (acknowledgment) al broker per indicare che il messaggio è stato processato con successo.
    channel.ack(delivery_info.delivery_tag)

    puts " [OK] Completato"
    puts "-"*5
  rescue StandardError => e
    # In caso di errore, rifiuto il messaggio e lo sposto nella coda DLQ.
    channel.reject(delivery_info.delivery_tag, false)
    puts " !KO! Messaggio rifiutato e spostato nella DLQ"
    puts " errore: #{e} - messaggio: #{e}"

    # N.B. nel mondo reale bisognerebbe capire se è fattibile mettere il messaggio in chiaro nei log
    AppLogger.logger.error(" !KO! Error durante il processamento del messaggio: #{e.message} errore: #{e}")

  end
end
# N.B.
# - nel mondo reale sarebbe utile inserire anche una logica di riconnessione e un retry in caso di errore,
# - inoltre sarebbe bene settare un watchdog a livello di server per controllare che il consumer sia attivo,
# - In caso di errore il consumer si chiude, qui bisogna decidere se fare in modo di riattivarlo in automatico o, ricevuto l'errore,
# intervenire per capire e porvi rimedio
