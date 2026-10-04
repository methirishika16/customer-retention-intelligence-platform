"""
Generate the Tableau workbook (tableau/customer_retention.twb) from code.

    python python/export_tableau_data.py     # 1. refresh the CSVs in tableau/data/
    python tableau/build_workbook.py         # 2. write the workbook
    open tableau/customer_retention.twb      # 3. open in Tableau Public / Desktop

A .twb is plain XML: data source definitions, calculated fields, worksheets and
dashboards. Generating it keeps the dashboards reproducible and reviewable in Git.
Layout follows docs/tableau_dashboard_spec.md.
"""

from pathlib import Path
from xml.sax.saxutils import escape, quoteattr

HERE = Path(__file__).resolve().parent
DATA_DIR = HERE / "data"
OUT = HERE / "customer_retention.twb"

W, H = 1200, 800          # dashboard size in pixels
BLUE, ORANGE, AQUA = "#2a78d6", "#eb6834", "#1baf7a"
GREY, LIGHT_GREY = "#a8a79f", "#d6d5cf"
NAVY, SKY = "#104281", "#86b6ef"
TEXT, TEXT_2 = "#0b0b0b", "#52514e"

# ------------------------------------------------------------------------------------
# Data sources: CSV columns and their Tableau types
# ------------------------------------------------------------------------------------
S, I, R, D, B = "string", "integer", "real", "date", "boolean"
SOURCES = {
    "customers": [
        ("customer_unique_id", S), ("customer_state", S), ("first_purchase_date", D), ("last_purchase_date", D),
        ("recency_days", R), ("order_count", I), ("purchase_days", I), ("total_revenue", R), ("avg_order_value", R),
        ("tenure_days", R), ("items_per_order", R), ("avg_review_score_observed", R), ("had_late_delivery", I),
        ("is_repeat_customer", I), ("rfm_segment", S), ("r_score", I), ("f_score", I), ("m_score", I),
        ("activity_status", S), ("value_tier", S), ("return_probability", R), ("expected_revenue_180d", R),
        ("risk_tier", S), ("customer_group", S), ("next_best_action", S), ("action_reason", S),
        ("action_cost_brl", R), ("priority_score", R), ("priority_rank", I), ("cumulative_action_cost_brl", R),
        ("scored_as_of", D), ("model_version", S), ("acquisition_month", D), ("avg_review_score", R),
        ("late_delivery_count", I),
    ],
    "monthly_revenue": [
        ("purchase_month", D), ("orders", I), ("unique_customers", I), ("revenue", R), ("avg_order_value", R),
        ("items_per_order", R), ("new_customers", I), ("returning_customers", I), ("new_customer_revenue", R),
        ("returning_customer_revenue", R), ("returning_customer_share", R), ("cumulative_revenue", R),
        ("is_low_volume_month", B),
    ],
    "cohort_retention": [
        ("cohort_key", S), ("acquisition_month", D), ("months_since_acquisition", I), ("cohort_customers", I),
        ("active_customers", I), ("retention_rate", R), ("is_small_cohort", B),
    ],
    "category_performance": [
        ("product_category", S), ("items_sold", I), ("orders", I), ("unique_customers", I), ("products_sold", I),
        ("item_revenue", R), ("freight_revenue", R), ("avg_item_price", R), ("item_revenue_share", R),
        ("revenue_rank", I), ("avg_review_score", R),
    ],
    "model_lift_by_decile": [
        ("decile", I), ("customers", I), ("returned", I), ("predicted_rate", R), ("actual_rate", R),
        ("lift", R), ("cumulative_capture", R),
    ],
}
DS = {name: f"federated.{name.replace('_', '')}" for name in SOURCES}
PARAM = "[Parameters].[Parameter 1]"

# Calculated fields: (datasource, id, caption, formula, datatype, role, type)
CALCS = [
    # Executive KPIs (aggregate calcs; numbers formatted with label text around them)
    ("customers", "kpi_revenue_m", "KPI Revenue (M)", "ROUND(SUM([total_revenue]) / 1000000, 2)", R, "measure", "quantitative"),
    ("customers", "kpi_orders", "KPI Orders", "SUM([order_count])", I, "measure", "quantitative"),
    ("customers", "kpi_customers", "KPI Customers", "COUNTD([customer_unique_id])", I, "measure", "quantitative"),
    ("customers", "kpi_aov", "KPI AOV", "ROUND(SUM([total_revenue]) / SUM([order_count]), 2)", R, "measure", "quantitative"),
    ("customers", "kpi_repeat_pct", "KPI Repeat Rate %", "ROUND(100 * SUM(IIF([order_count] >= 2, 1, 0)) / COUNT([customer_unique_id]), 2)", R, "measure", "quantitative"),
    ("customers", "kpi_high_value", "KPI High-Value Customers", "SUM(IIF([value_tier] = 'High', 1, 0))", I, "measure", "quantitative"),
    ("customers", "kpi_high_value_rev_pct", "KPI High-Value Revenue %", "ROUND(100 * SUM(IIF([value_tier] = 'High', [total_revenue], 0)) / SUM([total_revenue]), 1)", R, "measure", "quantitative"),
    # Segmentation helpers
    ("customers", "customer_count", "Customers", "COUNTD([customer_unique_id])", I, "measure", "quantitative"),
    ("customers", "lifecycle_stage", "Lifecycle Stage",
     "IF [customer_group] = 'Loyal Customer' THEN 'Loyal' ELSEIF [customer_group] = 'New Customer' THEN 'New' "
     "ELSEIF [risk_tier] = 'High' THEN 'At-risk' ELSE 'Other one-time' END", S, "dimension", "nominal"),
    ("customers", "revenue_band", "Revenue Band",
     "IF [total_revenue] < 50 THEN '1: < R$50' ELSEIF [total_revenue] < 100 THEN '2: R$50-99' "
     "ELSEIF [total_revenue] < 200 THEN '3: R$100-199' ELSEIF [total_revenue] < 500 THEN '4: R$200-499' "
     "ELSEIF [total_revenue] < 1000 THEN '5: R$500-999' ELSE '6: R$1,000+' END", S, "dimension", "nominal"),
    ("customers", "revenue_m", "Revenue (R$ M)", "SUM([total_revenue]) / 1000000", R, "measure", "quantitative"),
    ("customers", "avg_return_pct", "Avg Return Probability %", "ROUND(100 * AVG([return_probability]), 2)", R, "measure", "quantitative"),
    # Budget (driven by the parameter)
    ("customers", "within_budget", "Within Budget", f"[cumulative_action_cost_brl] <= {PARAM}", B, "dimension", "nominal"),
    ("customers", "kpi_budget_customers", "KPI Customers In Budget", f"SUM(IIF([cumulative_action_cost_brl] <= {PARAM}, 1, 0))", I, "measure", "quantitative"),
    ("customers", "kpi_budget_spend", "KPI Budget Spend", f"ROUND(SUM(IIF([cumulative_action_cost_brl] <= {PARAM}, [action_cost_brl], 0)), 0)", R, "measure", "quantitative"),
    ("customers", "kpi_budget_high_value", "KPI High-Value In Budget", f"SUM(IIF([cumulative_action_cost_brl] <= {PARAM} AND [value_tier] = 'High', 1, 0))", I, "measure", "quantitative"),
    ("customers", "kpi_budget_rev_pct", "KPI Revenue Share In Budget %", f"ROUND(100 * SUM(IIF([cumulative_action_cost_brl] <= {PARAM}, [total_revenue], 0)) / SUM([total_revenue]), 1)", R, "measure", "quantitative"),
    ("customers", "return_prob_pct", "Return Probability %", "ROUND(100 * [return_probability], 2)", R, "dimension", "ordinal"),
    ("customers", "customer_short_id", "Customer", "LEFT([customer_unique_id], 8)", S, "dimension", "nominal"),
    # Rates shown as percentages
    ("monthly_revenue", "returning_share_pct", "Returning Share %", "SUM([returning_customer_share]) * 100", R, "measure", "quantitative"),
    ("monthly_revenue", "revenue_k", "Revenue (R$ K)", "SUM([revenue]) / 1000", R, "measure", "quantitative"),
    ("cohort_retention", "retention_pct", "Retention %", "ROUND(100 * SUM([retention_rate]), 2)", R, "measure", "quantitative"),
    ("category_performance", "item_revenue_k", "Item Revenue (R$ K)", "SUM([item_revenue]) / 1000", R, "measure", "quantitative"),
]
CALC_INFO = {(c[0], c[1]): c for c in CALCS}

# Colour maps for dimensions (datasource-level so every sheet agrees)
COLOR_MAPS = {
    ("customers", "value_tier"): {"High": NAVY, "Medium": BLUE, "Low": SKY},
    ("customers", "risk_tier"): {"High": ORANGE, "Medium": GREY, "Low": LIGHT_GREY},
    ("customers", "activity_status"): {"Active": BLUE, "Cooling": ORANGE, "Inactive": GREY},
    ("customers", "within_budget"): {"true": ORANGE, "false": LIGHT_GREY},
}
SORT_ORDERS = {
    "value_tier": ["High", "Medium", "Low"],
    "risk_tier": ["High", "Medium", "Low"],
    "activity_status": ["Active", "Cooling", "Inactive"],
    "lifecycle_stage": ["Loyal", "New", "At-risk", "Other one-time"],
}


# ------------------------------------------------------------------------------------
# Field references
# ------------------------------------------------------------------------------------
class F:
    """A field placed on a shelf. kind: dim (discrete), cont (continuous measure),
    agg (aggregate calc), month_d / month_c (date truncated to month)."""

    def __init__(self, src, col, kind="dim", agg="Sum"):
        self.src, self.col, self.kind, self.agg = src, col, kind, agg

    @property
    def is_calc(self):
        return (self.src, self.col) in CALC_INFO

    @property
    def name(self):
        return f"Calculation_{self.col}" if self.is_calc else self.col

    @property
    def instance(self):
        n = self.name
        return {
            "dim": f"[none:{n}:nk]",
            "ord": f"[none:{n}:ok]",
            "qdim": f"[none:{n}:qk]",
            "cont": f"[{self.agg[:3].lower() if self.agg != 'CountD' else 'ctd'}:{n}:qk]",
            "agg": f"[usr:{n}:qk]",
            "month_d": f"[tmn:{n}:ok]",
            "month_c": f"[tmn:{n}:qk]",
        }[self.kind]

    @property
    def ref(self):
        return f"[{DS[self.src]}].{self.instance}"

    def instance_xml(self):
        n = self.name
        deriv, typ = {
            "dim": ("None", "nominal"), "ord": ("None", "ordinal"), "qdim": ("None", "quantitative"),
            "cont": (self.agg, "quantitative"), "agg": ("User", "quantitative"),
            "month_d": ("Month-Trunc", "ordinal"), "month_c": ("Month-Trunc", "quantitative"),
        }[self.kind]
        return (f"<column-instance column='[{n}]' derivation='{deriv}' name='{self.instance}' "
                f"pivot='key' type='{typ}' />")


def column_def(src, col):
    """Full <column> definition used inside datasource-dependencies and the datasource."""
    if (src, col) in CALC_INFO:
        _, cid, caption, formula, dtype, role, typ = CALC_INFO[(src, col)]
        return (f"<column caption={quoteattr(caption)} datatype='{dtype}' name='[Calculation_{cid}]' "
                f"role='{role}' type='{typ}'><calculation class='tableau' formula={quoteattr(formula)} /></column>")
    dtype = dict(SOURCES[src])[col]
    role = "measure" if dtype in (I, R) else "dimension"
    typ = "quantitative" if role == "measure" else ("ordinal" if dtype == D else "nominal")
    caption = col.replace("_", " ").title()
    return (f"<column caption={quoteattr(caption)} datatype='{dtype}' name='[{col}]' role='{role}' "
            f"type='{typ}' />")


def param_column():
    return ("<column caption='Marketing Budget (R$)' datatype='real' name='[Parameter 1]' "
            "param-domain-type='range' role='measure' type='quantitative' value='25000.'>"
            "<calculation class='tableau' formula='25000.' />"
            "<range granularity='5000.' max='200000.' min='0.' /></column>")


# ------------------------------------------------------------------------------------
# Worksheets
# ------------------------------------------------------------------------------------
class Sheet:
    def __init__(self, name, src, mark, rows=(), cols=(), color=None, size=None, text=(), detail=(),
                 tooltip=(), filters=(), sort=None, mark_color=BLUE, label=None, uses_param=False,
                 show_labels=False):
        self.name, self.src, self.mark = name, src, mark
        self.rows, self.cols = list(rows), list(cols)
        self.color, self.size = color, size
        self.text, self.detail, self.tooltip = list(text), list(detail), list(tooltip)
        self.filters, self.sort = list(filters), sort
        self.mark_color, self.label, self.uses_param = mark_color, label, uses_param
        self.show_labels = show_labels

    def fields(self):
        out = self.rows + self.cols + self.text + self.detail + self.tooltip
        out += [f for f in (self.color, self.size) if f]
        out += [flt[0] for flt in self.filters]
        if self.sort:
            out += [self.sort[0]] + ([self.sort[2]] if self.sort[2] else [])
        return out

    def xml(self):
        fields = self.fields()
        cols_needed, instances = [], []
        for f in fields:
            if f.col not in cols_needed:
                cols_needed.append(f.col)
            if f.instance_xml() not in instances:
                instances.append(f.instance_xml())
        # A calc that references other columns needs them declared too
        for f in list(fields):
            if f.is_calc:
                formula = CALC_INFO[(f.src, f.col)][3]
                for c, _ in SOURCES[f.src]:
                    if f"[{c}]" in formula and c not in cols_needed:
                        cols_needed.append(c)
        ds = DS[self.src]
        deps = "".join(column_def(self.src, c) for c in cols_needed) + "".join(instances)
        param_ds = "<datasource name='Parameters' />" if self.uses_param else ""
        param_deps = (f"<datasource-dependencies datasource='Parameters'>{param_column()}</datasource-dependencies>"
                      if self.uses_param else "")

        filters_xml, slices = "", []
        for flt in self.filters:
            f, kind, value = flt
            if kind == "member":
                member = value if isinstance(value, str) and value in ("true", "false") else f"&quot;{escape(str(value))}&quot;"
                filters_xml += (f"<filter class='categorical' column='{f.ref}'>"
                                f"<groupfilter function='member' level='{f.instance}' member='{member}' "
                                f"user:ui-domain='database' user:ui-enumeration='inclusive' user:ui-marker='enumerate' />"
                                f"</filter>")
            elif kind == "range":
                lo, hi = value
                filters_xml += (f"<filter class='quantitative' column='{f.ref}' included-values='in-range'>"
                                f"<min>{lo}</min><max>{hi}</max></filter>")
            elif kind == "all":   # shown as an interactive quick filter on the dashboard
                filters_xml += (f"<filter class='categorical' column='{f.ref}'>"
                                f"<groupfilter function='level-members' level='{f.instance}' "
                                f"user:ui-enumeration='all' user:ui-marker='enumerate' /></filter>")
            slices.append(f.ref)
        slices_xml = ("<slices>" + "".join(f"<column>{s}</column>" for s in slices) + "</slices>") if slices else ""

        sort_xml = ""
        for f in self.rows + self.cols + ([self.color] if self.color else []):
            if f.kind == "dim" and f.col in SORT_ORDERS and not sort_xml.count(f.ref):
                buckets = "".join(f"<bucket>&quot;{v}&quot;</bucket>" for v in SORT_ORDERS[f.col])
                sort_xml += (f"<manual-sort column='{f.ref}' direction='ASC'><dictionary>{buckets}</dictionary>"
                             f"</manual-sort>")
        if self.sort:
            f, direction, using = self.sort
            sort_xml += f"<computed-sort column='{f.ref}' direction='{direction}' using='{using.ref}' />"

        enc = ""
        if self.color:
            enc += f"<color column='{self.color.ref}' />"
        if self.size:
            enc += f"<size column='{self.size.ref}' />"
        for f in self.text:
            enc += f"<text column='{f.ref}' />"
        for f in self.detail:
            enc += f"<lod column='{f.ref}' />"
        for f in self.tooltip:
            enc += f"<tooltip column='{f.ref}' />"

        label_xml = ""
        if self.label:
            runs = ""
            for part in self.label:
                if isinstance(part, F):
                    runs += f"<run bold='true' fontcolor='{TEXT}' fontsize='26'>&lt;{part.ref}&gt;</run>"
                elif part == "\n":
                    runs += "<run>Æ&#10;</run>"
                else:
                    size, color, txt = part
                    runs += f"<run fontcolor='{color}' fontsize='{size}'>{escape(txt)}</run>"
            label_xml = f"<customized-label><formatted-text>{runs}</formatted-text></customized-label>"

        mark_style = ""
        if not self.color:
            mark_style += f"<format attr='mark-color' value='{self.mark_color}' />"
        if self.show_labels:
            mark_style += "<format attr='mark-labels-show' value='true' />"
        style = f"<style><style-rule element='mark'>{mark_style}</style-rule></style>" if mark_style else "<style />"

        rows = " / ".join(f.ref for f in self.rows)
        cols = " / ".join(f.ref for f in self.cols)
        return f"""
    <worksheet name={quoteattr(self.name)}>
      <table>
        <view>
          <datasources><datasource caption='{self.src}' name='{ds}' />{param_ds}</datasources>
          {param_deps}
          <datasource-dependencies datasource='{ds}'>{deps}</datasource-dependencies>
          {filters_xml}
          {sort_xml}
          {slices_xml}
          <aggregation value='true' />
        </view>
        <style />
        <panes>
          <pane selection-relaxation-option='selection-relaxation-allow'>
            <view><breakdown value='auto' /></view>
            <mark class='{self.mark}' />
            {label_xml}
            <encodings>{enc}</encodings>
            {style}
          </pane>
        </panes>
        <rows>{rows}</rows>
        <cols>{cols}</cols>
      </table>
    </worksheet>"""


def kpi(name, caption, field, prefix="", suffix="", sub=None, uses_param=False):
    label = [(11, TEXT_2, caption), "\n", (26, TEXT, prefix), field, (26, TEXT, suffix)]
    text = [field]
    if sub:
        sub_field, sub_prefix, sub_suffix = sub
        label += ["\n", (10, TEXT_2, sub_prefix), sub_field, (10, TEXT_2, sub_suffix)]
        text.append(sub_field)
    return Sheet(name, "customers", "Text", text=text, label=label, uses_param=uses_param)


c = lambda col, kind="dim", agg="Sum": F("customers", col, kind, agg)  # noqa: E731
SHEETS = [
    # ---- 1. Executive Overview
    kpi("1.1a KPI Revenue", "Revenue", c("kpi_revenue_m", "agg"), "R$ ", "M"),
    kpi("1.1b KPI Orders", "Orders", c("kpi_orders", "agg")),
    kpi("1.1c KPI Customers", "Customers", c("kpi_customers", "agg")),
    kpi("1.1d KPI AOV", "Average order value", c("kpi_aov", "agg"), "R$ "),
    kpi("1.1e KPI Repeat", "Repeat purchase rate", c("kpi_repeat_pct", "agg"), "", "%"),
    kpi("1.1f KPI High Value", "High-value customers", c("kpi_high_value", "agg"),
        sub=(c("kpi_high_value_rev_pct", "agg"), "", "% of revenue")),
    Sheet("1.2 Monthly revenue", "monthly_revenue", "Line",
          rows=[F("monthly_revenue", "revenue_k", "agg")], cols=[F("monthly_revenue", "purchase_month", "month_c")],
          filters=[(F("monthly_revenue", "is_low_volume_month"), "member", "false")]),
    Sheet("1.3 New customers per month", "monthly_revenue", "Bar",
          rows=[F("monthly_revenue", "new_customers", "cont")], cols=[F("monthly_revenue", "purchase_month", "month_d")],
          filters=[(F("monthly_revenue", "is_low_volume_month"), "member", "false")]),
    Sheet("1.4 Returning customer share", "monthly_revenue", "Line",
          rows=[F("monthly_revenue", "returning_share_pct", "agg")], cols=[F("monthly_revenue", "purchase_month", "month_c")],
          filters=[(F("monthly_revenue", "is_low_volume_month"), "member", "false")], mark_color=AQUA),

    # ---- 2. Customer Segmentation
    Sheet("2.1 RFM segments", "customers", "Bar",
          rows=[c("rfm_segment")], cols=[c("revenue_m", "agg")], text=[c("customer_count", "agg")],
          sort=(c("rfm_segment"), "DESC", c("revenue_m", "agg")), show_labels=True,
          filters=[(c("customer_state"), "all", None)]),
    Sheet("2.2 Recency x Monetary", "customers", "Square",
          rows=[c("m_score", "ord")], cols=[c("r_score", "ord")], color=c("customer_count", "agg"),
          text=[c("customer_count", "agg")]),
    Sheet("2.3 Value distribution", "customers", "Bar",
          rows=[c("customer_count", "agg")], cols=[c("revenue_band")], text=[c("customer_count", "agg")],
          show_labels=True),
    Sheet("2.4 Lifecycle stage", "customers", "Bar",
          rows=[c("lifecycle_stage")], cols=[c("customer_count", "agg")], text=[c("customer_count", "agg")],
          show_labels=True),

    # ---- 3. Retention Intelligence
    Sheet("3.1 Risk distribution", "customers", "Bar",
          rows=[c("customer_count", "agg")], cols=[c("risk_tier")], color=c("risk_tier"),
          text=[c("customer_count", "agg")], tooltip=[c("avg_return_pct", "agg")], show_labels=True),
    Sheet("3.2 Value x risk", "customers", "Square",
          rows=[c("value_tier")], cols=[c("risk_tier")], color=c("revenue_m", "agg"),
          text=[c("customer_count", "agg"), c("revenue_m", "agg")]),
    Sheet("3.3 Activity by value tier", "customers", "Bar",
          rows=[c("value_tier")], cols=[c("customer_count", "agg")], color=c("activity_status")),
    Sheet("3.4 Cohort retention", "cohort_retention", "Square",
          rows=[F("cohort_retention", "acquisition_month", "month_d")],
          cols=[F("cohort_retention", "months_since_acquisition", "ord")],
          color=F("cohort_retention", "retention_pct", "agg"), text=[F("cohort_retention", "retention_pct", "agg")],
          filters=[(F("cohort_retention", "is_small_cohort"), "member", "false"),
                   (F("cohort_retention", "months_since_acquisition", "qdim"), "range", (1, 12))]),

    # ---- 4. Growth Opportunities
    Sheet("4.1 Opportunity map", "customers", "Circle",
          rows=[c("avg_return_pct", "agg")], cols=[c("revenue_m", "agg")], size=c("customer_count", "agg"),
          text=[c("customer_group")], detail=[c("customer_group")], show_labels=True),
    Sheet("4.2 Next best actions", "customers", "Bar",
          rows=[c("next_best_action")], cols=[c("customer_count", "agg")], text=[c("customer_count", "agg")],
          sort=(c("next_best_action"), "DESC", c("customer_count", "agg")), show_labels=True),
    Sheet("4.3 Category performance", "category_performance", "Bar",
          rows=[F("category_performance", "product_category")], cols=[F("category_performance", "item_revenue_k", "agg")],
          color=F("category_performance", "avg_review_score", "cont", "Avg"),
          sort=(F("category_performance", "product_category"), "DESC", F("category_performance", "item_revenue_k", "agg")),
          filters=[(F("category_performance", "revenue_rank", "qdim"), "range", (1, 15))]),

    # ---- 5. Marketing Prioritization
    kpi("5.2a KPI Reached", "Customers reached", c("kpi_budget_customers", "agg"), uses_param=True),
    kpi("5.2b KPI Spend", "Budget used", c("kpi_budget_spend", "agg"), "R$ ", uses_param=True),
    kpi("5.2c KPI High Value", "High-value customers reached", c("kpi_budget_high_value", "agg"), uses_param=True),
    kpi("5.2d KPI Revenue Share", "Share of historical revenue", c("kpi_budget_rev_pct", "agg"), "", "%", uses_param=True),
    Sheet("5.3 Budget curve", "customers", "Line",
          rows=[c("cumulative_action_cost_brl", "cont")], cols=[c("priority_rank", "qdim")],
          color=c("within_budget"), uses_param=True,
          filters=[(c("priority_rank", "qdim"), "range", (1, 40000))]),
    Sheet("5.4 Actions in budget", "customers", "Bar",
          rows=[c("next_best_action")], cols=[c("customer_count", "agg")], text=[c("customer_count", "agg")],
          filters=[(c("within_budget"), "member", "true")], uses_param=True, mark_color=ORANGE, show_labels=True,
          sort=(c("next_best_action"), "DESC", c("customer_count", "agg"))),
    Sheet("5.5 Priority list", "customers", "Text",
          rows=[c("priority_rank", "ord"), c("customer_short_id"), c("customer_state"), c("customer_group"),
                c("next_best_action"), c("return_prob_pct", "ord")],
          cols=[], text=[c("priority_score", "cont", "Sum")],
          filters=[(c("within_budget"), "member", "true"), (c("priority_rank", "qdim"), "range", (1, 100))],
          uses_param=True),

    # ---- Appendix: model card
    Sheet("6.1 Model lift by decile", "model_lift_by_decile", "Bar",
          rows=[F("model_lift_by_decile", "lift", "cont")], cols=[F("model_lift_by_decile", "decile", "ord")],
          text=[F("model_lift_by_decile", "lift", "cont")], show_labels=True),
]
SHEET_BY_NAME = {s.name: s for s in SHEETS}


# ------------------------------------------------------------------------------------
# Dashboards (floating layout, coordinates in pixels on a 1200 x 800 canvas)
# ------------------------------------------------------------------------------------
NAV = ["Executive Overview", "Customer Segmentation", "Retention Intelligence",
       "Growth Opportunities", "Marketing Prioritization", "Model Card"]

DASHBOARDS = [
    ("Executive Overview",
     "Customer Retention Intelligence: Executive Overview",
     "Olist marketplace · valid purchases Sep 2016 – Aug 2018 · revenue in BRL",
     [("1.1a KPI Revenue", 20, 110, 185, 100), ("1.1b KPI Orders", 215, 110, 185, 100),
      ("1.1c KPI Customers", 410, 110, 185, 100), ("1.1d KPI AOV", 605, 110, 185, 100),
      ("1.1e KPI Repeat", 800, 110, 185, 100), ("1.1f KPI High Value", 995, 110, 185, 100),
      ("1.2 Monthly revenue", 20, 225, 1160, 270),
      ("1.3 New customers per month", 20, 505, 575, 270), ("1.4 Returning customer share", 605, 505, 575, 270)],
     "Returning customers grew from ~0.1% to ~3% of monthly buyers, still a small minority. "
     "Low-volume months (2016-09, 2016-12, 2018-09) are excluded."),
    ("Customer Segmentation",
     "Who Are Our Customers?",
     "RFM segments, value distribution and lifecycle stage · 94,990 customers as of 2018-09-03",
     [("2.1 RFM segments", 20, 110, 580, 340), ("2.2 Recency x Monetary", 610, 110, 570, 340),
      ("2.3 Value distribution", 20, 460, 580, 310), ("2.4 Lifecycle stage", 610, 460, 570, 310)],
     "Recency (R) and Monetary (M) scores run 1-5 (5 = best). Frequency is omitted from the matrix: 97.8% of customers bought once."),
    ("Retention Intelligence",
     "Who Is Slipping Away?",
     "Predicted return likelihood, high-value customers at risk and cohort retention",
     [("3.1 Risk distribution", 20, 110, 370, 300), ("3.2 Value x risk", 400, 110, 380, 300),
      ("3.3 Activity by value tier", 790, 110, 390, 300), ("3.4 Cohort retention", 20, 420, 1160, 350)],
     "Risk tiers rank customers by the model's predicted chance of buying again within 180 days. "
     "No customer is labelled 'churned': the data has no churn event."),
    ("Growth Opportunities",
     "Where Is the Opportunity?",
     "Retention groups, recommended next-best actions and category performance",
     [("4.1 Opportunity map", 20, 110, 580, 340), ("4.2 Next best actions", 610, 110, 570, 340),
      ("4.3 Category performance", 20, 460, 1160, 310)],
     "Bubble size = customers. Category colour = average review score (low scores stand out). "
     "Expected revenue figures are model estimates if no action is taken."),
    ("Marketing Prioritization",
     "Who Should We Contact First?",
     "Customers ranked by priority score · move the budget slider · action costs are illustrative",
     [("5.2a KPI Reached", 320, 110, 210, 100), ("5.2b KPI Spend", 540, 110, 210, 100),
      ("5.2c KPI High Value", 760, 110, 210, 100), ("5.2d KPI Revenue Share", 980, 110, 200, 100),
      ("5.3 Budget curve", 20, 220, 580, 250), ("5.4 Actions in budget", 610, 220, 570, 250),
      ("5.5 Priority list", 20, 480, 1160, 290)],
     "Priority = 45% value + 35% predicted return likelihood + 20% urgency. "
     "The effect of each action must be measured with an A/B test."),
    ("Model Card",
     "How Good Is the Model?",
     "Out-of-time test: customers as of 2018-03-01, did they buy again within 180 days?",
     [("6.1 Model lift by decile", 20, 110, 1160, 520)],
     "ROC-AUC 0.586 (random 0.519). Top 10% lift 2.0x vs 1.9x for an RFM rule and 1.5x for 'most recent first'. "
     "Use scores to rank customers, not as exact probabilities."),
]


def units(x, y, w, h):
    return (round(x * 100000 / W), round(y * 100000 / H), round(w * 100000 / W), round(h * 100000 / H))


def text_zone(zid, x, y, w, h, runs):
    ux, uy, uw, uh = units(x, y, w, h)
    return (f"<zone h='{uh}' id='{zid}' type-v2='text' w='{uw}' x='{ux}' y='{uy}'>"
            f"<formatted-text>{runs}</formatted-text></zone>")


def dashboard_xml(name, title, subtitle, sheets, caption):
    zid = iter(range(2, 1000))
    zones = []
    zones.append(text_zone(next(zid), 20, 12, 1160, 34,
                           f"<run bold='true' fontcolor='{TEXT}' fontsize='18'>{escape(title)}</run>"))
    zones.append(text_zone(next(zid), 20, 44, 1160, 22,
                           f"<run fontcolor='{TEXT_2}' fontsize='11'>{escape(subtitle)}</run>"))
    nav = "   ·   ".join(n if n != name else f"[{n}]" for n in NAV)
    zones.append(text_zone(next(zid), 20, 70, 1160, 22, f"<run fontcolor='{BLUE}' fontsize='10'>{escape(nav)}</run>"))
    for sheet_name, x, y, w, h in sheets:
        ux, uy, uw, uh = units(x, y, w, h)
        is_kpi = "KPI" in sheet_name
        show_title = "false" if is_kpi else "true"
        zones.append(f"<zone h='{uh}' id='{next(zid)}' name={quoteattr(sheet_name)} show-title='{show_title}' "
                     f"w='{uw}' x='{ux}' y='{uy}' />")
    if name == "Marketing Prioritization":
        ux, uy, uw, uh = units(20, 110, 290, 100)
        zones.append(f"<zone h='{uh}' id='{next(zid)}' mode='slider' param='{PARAM}' type-v2='paramctrl' "
                     f"w='{uw}' x='{ux}' y='{uy}' />")
    if name == "Customer Segmentation":
        ux, uy, uw, uh = units(900, 70, 280, 34)
        state = F("customers", "customer_state")
        zones.append(f"<zone h='{uh}' id='{next(zid)}' mode='checkdropdown' name='2.1 RFM segments' "
                     f"param='{state.ref}' type-v2='filter' w='{uw}' x='{ux}' y='{uy}' />")
    zones.append(text_zone(next(zid), 20, 776, 1160, 22, f"<run fontcolor='{TEXT_2}' fontsize='9'>{escape(caption)}</run>"))
    root = f"<zone h='100000' id='1' type-v2='layout-basic' w='100000' x='0' y='0' />"
    return f"""
    <dashboard name={quoteattr(name)}>
      <style />
      <size maxheight='{H}' maxwidth='{W}' minheight='{H}' minwidth='{W}' />
      <zones>{root}{''.join(zones)}</zones>
    </dashboard>"""


# ------------------------------------------------------------------------------------
# Data source XML
# ------------------------------------------------------------------------------------
def datasource_xml(src):
    ds = DS[src]
    tc = f"textscan.{src.replace('_', '')}"
    cols = "".join(f"<column datatype='{t}' name='{c}' ordinal='{i}' />" for i, (c, t) in enumerate(SOURCES[src]))
    calcs = "".join(column_def(src, cid) for (s, cid) in CALC_INFO if s == src)
    styles = ""
    for (s, col), mapping in COLOR_MAPS.items():
        if s != src:
            continue
        f = F(s, col)
        maps = "".join(
            f"<map to='{color}'><bucket>{v if v in ('true', 'false') else '&quot;' + v + '&quot;'}</bucket></map>"
            for v, color in mapping.items())
        styles += f"<encoding attr='color' field='{f.instance}' type='palette'>{maps}</encoding>"
    style_xml = f"<style><style-rule element='mark'>{styles}</style-rule></style>" if styles else ""
    return f"""
    <datasource caption='{src}' inline='true' name='{ds}' version='18.1'>
      <connection class='federated'>
        <named-connections>
          <named-connection caption='{src}' name='{tc}'>
            <connection class='textscan' directory={quoteattr(str(DATA_DIR))} filename='{src}.csv' password='' server='' />
          </named-connection>
        </named-connections>
        <relation connection='{tc}' name='{src}.csv' table='[{src}#csv]' type='table'>
          <columns character-set='UTF-8' header='yes' locale='en_US' separator=','>{cols}</columns>
        </relation>
      </connection>
      <aliases enabled='yes' />
      {calcs}
      <layout dim-ordering='alphabetic' measure-ordering='alphabetic' show-structure='true' />
      {style_xml}
    </datasource>"""


def build():
    missing = [s for s in SOURCES if not (DATA_DIR / f"{s}.csv").exists()]
    if missing:
        raise SystemExit(f"Missing CSVs {missing}: run python python/export_tableau_data.py first")
    parameters = (f"<datasource hasconnection='false' inline='true' name='Parameters' version='18.1'>"
                  f"<aliases enabled='yes' />{param_column()}</datasource>")
    datasources = parameters + "".join(datasource_xml(s) for s in SOURCES)
    worksheets = "".join(s.xml() for s in SHEETS)
    dashboards = "".join(dashboard_xml(*d) for d in DASHBOARDS)
    windows = "".join(f"<window class='dashboard' maximized='true' name={quoteattr(d[0])}><viewpoints /></window>"
                      for d in DASHBOARDS)
    windows += "".join(f"<window class='worksheet' hidden='true' name={quoteattr(s.name)} />" for s in SHEETS)
    xml = f"""<?xml version='1.0' encoding='utf-8' ?>
<workbook original-version='18.1' source-build='2024.2.0 (20242.24.0613.0835)' source-platform='mac' version='18.1' xmlns:user='http://www.tableausoftware.com/xml/user'>
  <preferences>
    <preference name='ui.encoding.shelf.height' value='24' />
    <preference name='ui.shelf.height' value='26' />
  </preferences>
  <datasources>{datasources}
  </datasources>
  <worksheets>{worksheets}
  </worksheets>
  <dashboards>{dashboards}
  </dashboards>
  <windows source-height='30'>{windows}</windows>
</workbook>
"""
    OUT.write_text(xml, encoding="utf-8")
    print(f"Wrote {OUT.relative_to(HERE.parent)}: {len(SHEETS)} worksheets, {len(DASHBOARDS)} dashboards")


if __name__ == "__main__":
    build()
