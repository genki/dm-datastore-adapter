require 'java'
require 'addressable/uri'

module DataMapper
  module Adapters
    class DataStoreAdapter < AbstractAdapter
      class InvalidConditionError < StandardError; end

      module DS
        unless const_defined?("Service")
          import com.google.appengine.api.datastore.DatastoreServiceFactory
          import com.google.appengine.api.datastore.Entity
          import com.google.appengine.api.datastore.FetchOptions
          import com.google.appengine.api.datastore.KeyFactory
          import com.google.appengine.api.datastore.Key
          import com.google.appengine.api.datastore.EntityNotFoundException
          import com.google.appengine.api.datastore.Query
          import com.google.appengine.api.datastore.Text
          Service = DatastoreServiceFactory.datastore_service
        end
      end

      def create(resources)
        created = 0
        resources.each do |resource|
          entity = DS::Entity.new(resource.class.name)
          resource.attributes.each do |key, value|
            ds_set(entity, resource.model.properties[key], value)
          end
          begin
            ds_key = ds_service_put(entity)
          rescue Exception
          else
            ds_id = ds_key.get_id
            resource.model.key.each do |property|
              resource.attribute_set property.field, ds_id
              ds_set(entity, property, ds_id)
            end
            ds_service_put(entity)
            created += 1
          end
        end
        created
      end

      def update(attributes, query)
        updated = 0
        resources = read_many(query)
        resources.each do |resource|
          entity = ds_service_get(ds_key_from_resource(resource))
          attributes.each do |property, value|
            ds_set(entity, property, value)
          end
          begin
            ds_key = ds_service_put(entity)
          rescue Exception
          else
            resource.model.key.each do |property|
              resource.attribute_set property.field, ds_key.get_id
            end
            updated += 1
          end
        end
        updated
      end

      def delete(query)
        resources = read_many(query)
        ds_keys = resources.map do |resource|
          begin
            ds_key_from_resource(resource)
          rescue Exception
            nil
          end
        end.compact
        ds_service_delete(ds_keys.to_java(DS::Key))
        ds_keys.size
      rescue Exception
        0
      end

      def read_many(query)
        Collection.new(query) do |collection|
          loop do
            negas, posis = {}, {}
            q = build_query(query) do |op, property, value|
              negas[property] = value if op == :not
              posis[property] = value if op == :eql
            end
            fo = build_fetch_option(query)
            iter = if fo
              DS::Service.prepare(q).as_iterable(fo)
            else
              DS::Service.prepare(q).as_iterable
            end
            iter.each do |entity|
              next if negative?(entity, negas)
              collection.load(query.fields.map do |property|
                property.key? ?
                  entity.key.get_id : ds_get(entity, property.field)
              end)
            end
            break if posis.empty?
            query = assert_query(query, posis)
          end
        end
      end

      def read_one(query)
        negas = {}
        q = build_query(query) do |op, property, value|
          negas[property] = value if op == :not
          if op == :eql
            raise InvalidConditionError,
              "OR condition is not afflowed for read_one"
          end
        end
        fo = build_fetch_option(query)
        entity = if fo
          DS::Service.prepare(q).as_iterable(fo).map{|i| break i}
        else 
          DS::Service.prepare(q).asSingleEntity
        end
        return nil if entity.blank?
        return nil if negative?(entity, negas)
        query.model.load(query.fields.map do |property|
          property.key? ? entity.key.get_id : ds_get(entity, property.field)
        end, query)
      end

      def aggregate(query)
        op = query.fields.find{|p| p.kind_of?(DataMapper::Query::Operator)}
        if op.nil?
          raise NotImplementedError, "No operator supplied."
        end
        if respond_to?(op.operator)
          self.send op.operator, query
        else
          raise NotImplementedError, "#{op.operator} is not supported yet."
        end
      end

      def count(query)
        result, limit = 0, query.limit
        loop do
          negas, posis = {}, {}
          q = build_query(query) do |op, property, value|
            negas[property] = value if op == :not
            posis[property] = value if op == :eql
          end
          result += DS::Service.prepare(q).countEntities
          unless negas.empty?
            result -= count(negate_query(query, negas)).first
          end
          break if posis.empty?
          break if limit && result >= limit
          query = assert_query(query, posis)
        end
        [limit ? [result, limit].min : result]
      end

    protected
      def normalize_uri(uri_or_options)
        if uri_or_options.kind_of?(Hash)
          uri_or_options = Addressable::URI.new(
            :scheme   => uri_or_options[:adapter].to_s,
            :user     => uri_or_options[:username],
            :password => uri_or_options[:password],
            :host     => uri_or_options[:host],
            :path     => uri_or_options[:database]).to_s
        end
        Addressable::URI.parse(uri_or_options)
      end

    private
      def ds_key_from_resource(resource)
        DS::KeyFactory.create_key(resource.class.name, resource.key.first)
      end

      def build_query(query)
        q = DS::Query.new(query.model.name)
        query.conditions.each do |tuple|
          next if tuple.size == 2
          op, property, value = *tuple
          ds_op = case op
          when :eql;  DS::Query::FilterOperator::EQUAL
          when :gt;   DS::Query::FilterOperator::GREATER_THAN
          when :gte;  DS::Query::FilterOperator::GREATER_THAN_OR_EQUAL
          when :lt;   DS::Query::FilterOperator::LESS_THAN
          when :lte;  DS::Query::FilterOperator::LESS_THAN_OR_EQUAL
          when :not;  yield(:not, property, value); next
          else next
          end
          if value.is_a?(Array)
            if op != :eql
              raise InvalidConditionError,
                "OR condition is allowed only for :eql operator"
            end
            value, *posis = *value
            yield(:eql, property, posis) unless posis.empty?
          end
          q = q.add_filter(property.field, ds_op, value)
        end
        query.order.each do |o|
          key = o.property.name.to_s
          if o.direction == :asc
            q = q.add_sort(key, DS::Query::SortDirection::ASCENDING)
          else
            q = q.add_sort(key, DS::Query::SortDirection::DESCENDING)
          end
        end
        q
      end

      def build_fetch_option(query)
        fo = nil
        if query.limit && query.limit != 1
          fo = DS::FetchOptions::Builder.with_limit(query.limit)
        end
        if query.offset
          if fo
            fo = fo.offset(query.offset)
          else
            fo = DS::FetchOptions::Builder.with_offset(query.offset)
          end
        end
        fo
      end

      def ds_get(entity, name)
        name = name.to_s
        if entity.has_property(name)
          result = entity.get_property(name)
          result.is_a?(DS::Text) ? result.value : result
        else
          nil
        end
      end

      def ds_set(entity, property, value)
        name = property.field.to_s
        case value
        when DateTime
          value = value.to_time
        end
        if value.is_a?(String) && value.length >= 500
          entity.set_property(name, DS::Text.new(value))
        else
          entity.set_property(name, value)
        end
      end

      def ds_service_get(ds_key)
        if tx = ds_transaction
          DS::Service.get(tx, ds_key)
        else
          DS::Service.get(ds_key)
        end
      end

      def ds_service_put(entity)
        if tx = ds_transaction
          DS::Service.put(tx, entity)
        else
          DS::Service.put(entity)
        end
      end

      def ds_service_delete(ds_key)
        if tx = ds_transaction
          DS::Service.delete(tx, ds_key)
        else
          DS::Service.delete(ds_key)
        end
      end

      def ds_transaction
        if tx = current_transaction
          primitive = tx.primitive_for(self)
          primitive.transaction
        else
          nil
        end
      end

      def negative?(entity, negas)
        negas.any? do |property, value|
          property.typecast(ds_get(entity, property.field)) == value
        end
      end

      def negate_query(query, negas)
        query = query.dup
        query.conditions.delete_if do |tuple| 
          tuple.size != 2 && tuple[0] == :not
        end
        negas.each do |property, value|
          query.conditions.push([:eql, property, value])
        end
        query
      end

      def assert_query(query, posis)
        query = query.dup
        property = posis.keys.first
        query.conditions.delete_if do |tuple|
          tuple.size != 2 && tuple[0] == :eql && tuple[1] == property
        end
        query.conditions.push([:eql, property, posis[property]])
        query
      end
    end

    DatastoreAdapter = DataStoreAdapter
  end
end
