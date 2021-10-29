require "google/protobuf/well_known_types"

module VagrantPlugins
  module CommandServe
    class Mappers
      [NilClass, Numeric, String, TrueClass, FalseClass,
        Struct, Google::Protobuf::ListValue].each do |type|
        Class.new(Mapper).class_eval("
          def self.name
            '#{type.name}ToProto'
          end

          def to_s
            '<#{type.name}ToProto:' + object_id.to_s + '>'
          end

          def initialize
            super(
              inputs: [Input.new(type: #{type.name})],
              output: Google::Protobuf::Value,
              func: method(:converter),
            )
          end

          def converter(input)
            Google::Protobuf::Value.new.tap { |v| v.from_ruby(input) }
          end
        ")
      end

      class HashToProto < Mapper
        def initialize
          super(
            inputs: [
              Input.new(type: Hash),
              Input.new(type: Mappers),
            ],
            output: SDK::Args::Hash,
            func: method(:converter),
          )
        end

        def converter(hash, mapper)
          fields = Hash.new.tap do |f|
            hash.each_pair do |k, v|
              r = mapper.map(v, to: Google::Protobuf::Any)
              f[k] = r
            end
          end
          SDK::Args::Hash.new(fields: fields)
        end
      end

      class HashFromProto < Mapper
        def initialize
          super(
            inputs: [
              Input.new(type: SDK::Args::Hash),
              Input.new(type: Mappers)
            ],
            output: Hash,
            func: method(:converter),
          )
        end

        def converter(proto, mapper)
          Hash.new.tap do |result|
            proto.fields.each_pair do |k, v|
              r = mapper.map(v)
              result[k.to_s] = r
            end
          end
        end
      end

      class ArrayToProto < Mapper
        def initialize
          super(
            inputs: [
              Input.new(type: Array),
              Input.new(type: Mappers),
            ],
            output: SDK::Args::Array,
            func: method(:converter),
          )
        end

        def converter(array, mapper)
          r = array.map do |v|
            mapper.map(v, to: Google::Protobuf::Any)
          end
          SDK::Args::Array.new(list: r)
        end
      end

      class ArrayFromProto < Mapper
        def initialize
          super(
            inputs: [
              Input.new(type: SDK::Args::Array),
              Input.new(type: Mappers),
            ],
            output: Array,
            func: method(:converter),
          )
        end

        def converter(proto, mapper)
          proto.list.map do |v|
            mapper.map(v)
          end
      class StructFromSpec < Mapper
        def initialize
          inputs = [].tap do |i|
            i << Input.new(type: SDK::FuncSpec::Value) { |arg|
              arg.type == "google.protobuf.Struct" &&
                !arg&.value&.value.nil?
            }
          end
          super(inputs: inputs, output: Hash, func: method(:converter))
        end

        def converter(proto)
          h = proto.value.unpack(Google::Protobuf::Struct).to_h
          h.transform_keys(&:to_sym)
        end
      end
    end
  end
end
