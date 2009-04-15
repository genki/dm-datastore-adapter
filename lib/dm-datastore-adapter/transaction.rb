module DataMapper
  module Adapters
    class DataStoreAdapter < AbstractAdapter
      class Transaction
        class AlreadyBeginError < StandardError; end

        attr_reader :transaction

        def begin
          raise AlreadyBeginError if @transaction
          @transaction = DS::Service.beginTransaction
        end

        def commit
          @transaction.commit
        end

        def rollback
          @transaction.rollback
        end

        def rollback_prepared
          @transaction.rollback
        end

        def prepare
          # TODO
        end

        def close
          @transaction = nil
        end
      end

      def transaction_primitive
        DataStoreAdapter::Transaction.new
      end

      def push_transaction(transaction)
        transactions(Thread::current) << transaction
      end

      def pop_transaction
        transactions(Thread::current).pop
      end

      def current_transaction
        transactions(Thread::current).last
      end

      def within_transaction?
        !current_transaction.nil?
      end

    private
      def transactions(thread)
        unless @transactions[thread]
          @transactions.delete_if do |key, value|
            !key.respond_to?(:alive?) || !key.alive?
          end
          @transactions[thread] = []
        end
        @transactions[thread]
      end
    end
  end
end
