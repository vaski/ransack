module Ransack
  class Visitor

    def accept(object)
      visit(object)
    end

    def can_accept?(object)
      respond_to? DISPATCH[object.class]
    end

    def visit_Array(object)
      object.map { |o| accept(o) }.compact
    end

    def visit_Ransack_Nodes_Condition(object)
      object.arel_predicate if object.valid?
    end

    def visit_Ransack_Nodes_Grouping(object)
      if object.combinator == Constants::OR
        visit_or(object)
      else
        visit_and(object)
      end
    end

    def visit_and(object)
      raise "not implemented"
    end

    def visit_or(object)
      nodes = object.values.map { |o| accept(o) }.compact
      return nil unless nodes.size > 0

      if nodes.size > 1
        nodes.inject(&:or)
      else
        nodes.first
      end
    end

    def visit_Ransack_Nodes_Sort(object)
      return unless object.valid?

      if sort_column_string?(object)
        with_nullif = Arel::Nodes::NamedFunction.new("NULLIF", [object.attr, Arel::Nodes.build_quoted('')])
      end

      case object.dir
        when 'asc'.freeze
          Arel::Nodes::Ascending.new(with_nullif || object.attr)
        when 'desc'.freeze
          Arel::Nodes::Descending.new(with_nullif || object.attr)
      end
    end

    def quoted?(object)
      raise "not implemented"
    end

    def visit(object)
      send(DISPATCH[object.class], object)
    end

    DISPATCH = Hash.new do |hash, klass|
      hash[klass] = "visit_#{
        klass.name.gsub(Constants::TWO_COLONS, Constants::UNDERSCORE)
        }"
    end

    private

    def sort_column_string?(object)
      model = object.parent.base_klass
      if model
        column_name = model.columns_hash[object.attr_name]
        column_name.type.to_s == 'string' if column_name
      end
    end
  end
end
