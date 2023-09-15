#!/usr/bin/env ruby
# shebang per indicare il percorso dell'interprete Ruby
# N.B. in locale uso RVM quindi non mi serve, non so però in che ambiente verrà eseguito e dunque lo aggiungo su tutti i file

require 'bunny'

# Importo il modulo AppLogger per la gestione dei log
require_relative 'app_logger'

module RabbitMQConfig
  # RabbitMQ GUI
  # http://localhost:15672/#/

  # Credenziali per accedere al broker RabbitMQ
  # N.B. nel mondo reale questi dati non saranno hardcoded
  HOST       = "localhost"
  PORT       = 5672
  USERNAME   = "guest"
  PASSWORD   = "guest"

  # Nome della coda
  QUEUE_NAME = "energy_queue"

  # Dead Letter Exchange
  # Coda per gestire i messaggi che non possono essere processati, verranno inseriti in una coda "morta"
  # con possibilità di essere processari manualmente in un secondo momento
  DLX_NAME   = "energy_queue.dead_letter"

  # Metodo per inizializzare la connessione a RabbitMQ
  # N.B. nel mondo reale sarebbe utile utilizzare un singleton model per gestire una sola connessione
  def self.connect
    # Tentativo di connessione al broker RabbitMQ con le credenziali fornite.
    begin
      connection = Bunny.new(
        host: HOST,
        port: PORT,
        username: USERNAME,
        password: PASSWORD
      )
      connection.start
    # In base agli hosts e alla configurazione sistemistica è possibile gestire in modo granulare le eccezioni
    # in mancanza di questi dati resto gestisco tutti gli errori in modo generico
    rescue StandardError => e
      # Gestione dell'eccezione nel caso la connessione al broker RabbitMQ fallisca.
      AppLogger.logger.error("!KO! Impossibile connettersi a RabbitMQ: #{e.message}")
      puts " !KO! Impossibile connettersi a RabbitMQ: #{e.message}"
      exit(1)
    end
    connection
  end

  # Metodo per creare una coda RabbitMQ
  def self.create_channel(connection)
    # Creazione di un nuovo canale sulla connessione esistente.
    channel = connection.create_channel
    # Abilita la conferma lato publisher
    channel.confirm_select

    channel
  end

  def self.create_queue(channel)
    # durable=true significa che i metadati della coda verranno salvati su disco
    # quindi In caso di un riavvio del broker, la coda e i suoi messaggi non verranno persi

    # Creazione del Dead Letter Exchange
    dlx   = channel.fanout(DLX_NAME, durable: true)

    # Creazione e configurazione della coda principale con Dead Letter Exchange Queue
    queue = channel.queue(QUEUE_NAME, durable: true, arguments: {'x-dead-letter-exchange' => DLX_NAME})

    # Associazione della coda al Dead Letter Exchange.
    queue.bind(dlx)

    queue

  end
end
