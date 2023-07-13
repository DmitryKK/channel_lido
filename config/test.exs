import Config

config :channel_lido,
  booking_processor: ChannelLido.BookingProcessorMock,
  broadway_producer_module: Broadway.DummyProducer,
  requester: ChannelLido.RequestMock

config :message_queue, adapter: :sandbox
