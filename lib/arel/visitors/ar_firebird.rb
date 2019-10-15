# frozen_string_literal: true

class Arel::Visitors::ArFirebird < Arel::Visitors::ToSql

  private

  def visit_Arel_Nodes_SelectStatement o, collector
    if o.with
      collector = visit o.with, collector
      collector << ' '
    end

    collector = o.cores.inject(collector) do |c, x|
      visit_Arel_Nodes_SelectCore(x, c, o)
    end

    unless o.orders.empty?
      collector << ' ORDER BY '
      o.orders.each_with_index do |x, i|
        collector << ', ' unless i == 0
        collector = visit(x, collector)
      end
    end

    collector
  end

  def visit_Arel_Nodes_SelectCore(core, collector, o)
    # We need to use the Arel::Nodes::SelectCore `core`
    # as well as Arel::Nodes::SelectStatement `o` in
    # contradiction to the super class because we access
    # the `visit_Arel_Nodes_SelectOptions` method because
    # we need to set our limit and offset in the select
    # clause (Firebird specific SQL)
    collector << 'SELECT'

    visit_Arel_Nodes_SelectOptions(o, collector)

    collector = maybe_visit core.set_quantifier, collector

    collect_nodes_for core.projections, collector, ' '

    if core.source && !core.source.empty?
      collector << ' FROM '
      collector = visit core.source, collector
    end

    collect_nodes_for core.wheres, collector, ' WHERE ', ' AND '
    collect_nodes_for core.groups, collector, ' GROUP BY '
    unless core.havings.empty?
      collector << ' HAVING '
      inject_join core.havings, collector, ' AND '
    end
    collect_nodes_for core.windows, collector, ' WINDOW '

    collector
  end

  def visit_Arel_Nodes_Limit(o, collector)
    collector << 'FIRST '
    visit o.expr, collector
  end

  def visit_Arel_Nodes_Offset(o, collector)
    collector << 'SKIP '
    visit o.expr, collector
  end
end
