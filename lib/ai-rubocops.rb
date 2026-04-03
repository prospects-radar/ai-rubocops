# frozen_string_literal: true

require_relative "ai-rubocops/version"

# Only load cops when running in RuboCop context
return unless defined?(RuboCop)

# === DesignSystem Cops ===

# Component API & Structure
require_relative "rubocop/cop/design_system/standard_api"
require_relative "rubocop/cop/design_system/component_hierarchy"
require_relative "rubocop/cop/design_system/no_render_in_atoms"
require_relative "rubocop/cop/design_system/no_raw_html_in_organisms"
require_relative "rubocop/cop/design_system/no_raw_html_in_views"
require_relative "rubocop/cop/design_system/badge_valid_color"
require_relative "rubocop/cop/design_system/class_parameter"
require_relative "rubocop/cop/design_system/data_parameter"
require_relative "rubocop/cop/design_system/no_preline_in_glass_morph"
require_relative "rubocop/cop/design_system/no_hardcoded_html_components"
require_relative "rubocop/cop/design_system/use_real_badge_component"
require_relative "rubocop/cop/design_system/no_class_on_badge"
require_relative "rubocop/cop/design_system/use_real_heading_component"
require_relative "rubocop/cop/design_system/use_real_separator_component"
require_relative "rubocop/cop/design_system/use_real_score_badge_component"
require_relative "rubocop/cop/design_system/no_component_database_queries"
require_relative "rubocop/cop/design_system/component_tid_usage"
require_relative "rubocop/cop/design_system/component_test_id_required"
require_relative "rubocop/cop/design_system/no_inline_event_handlers"

# Design Token & Style Enforcement
require_relative "rubocop/cop/design_system/no_raw_buttons_in_views"
require_relative "rubocop/cop/design_system/no_raw_link_tags"
require_relative "rubocop/cop/design_system/no_inline_styles"
require_relative "rubocop/cop/design_system/enforce_design_token_classes"
require_relative "rubocop/cop/design_system/button_variant_required"
require_relative "rubocop/cop/design_system/glass_card_variant"
require_relative "rubocop/cop/design_system/single_primary_button_per_section"

# Modal & Wizard Enforcement
require_relative "rubocop/cop/design_system/modal_usage"
require_relative "rubocop/cop/design_system/wizard_structure"

# Deprecation Enforcement
require_relative "rubocop/cop/design_system/no_new_preline_usage"
require_relative "rubocop/cop/design_system/no_new_tailwind_usage"
require_relative "rubocop/cop/design_system/no_embedded_css_in_layouts"
require_relative "rubocop/cop/design_system/no_legacy_new_ui_reference"
require_relative "rubocop/cop/design_system/no_raw_bi_icon_classes"
require_relative "rubocop/cop/design_system/no_raw_svg_in_components"
require_relative "rubocop/cop/design_system/lookbook_only_glass_morph"
require_relative "rubocop/cop/design_system/interactive_aria_required"

# === Architecture Cops ===

# Service Layer
require_relative "rubocop/cop/architecture/service_inheritance"
require_relative "rubocop/cop/architecture/no_current_user_parameter"
require_relative "rubocop/cop/architecture/service_action_dispatch"
require_relative "rubocop/cop/architecture/service_response_format"
require_relative "rubocop/cop/architecture/service_rescue_from"
require_relative "rubocop/cop/architecture/controller_service_result_check"

# Controller Layer
require_relative "rubocop/cop/architecture/controller_business_logic"
require_relative "rubocop/cop/architecture/no_controller_authorization"

# I18n
require_relative "rubocop/cop/architecture/i18n_no_default"

# === RAAF Cops (AI Agent Framework) ===
require_relative "rubocop/cop/raaf/agent_run"
require_relative "rubocop/cop/raaf/prompt_methods"
require_relative "rubocop/cop/raaf/agent_inheritance"
require_relative "rubocop/cop/raaf/agent_tool_scope"
require_relative "rubocop/cop/raaf/agent_no_inline_orchestration"
require_relative "rubocop/cop/raaf/schema_nested_array_required"
require_relative "rubocop/cop/raaf/prompt_language_instructions"
require_relative "rubocop/cop/raaf/logger"
require_relative "rubocop/cop/raaf/prompt_user_input_escaping"
require_relative "rubocop/cop/raaf/agent_schema_validation"
require_relative "rubocop/cop/raaf/agent_context_immutability"

# === MultiTenancy Cops ===
require_relative "rubocop/cop/multi_tenancy/tenant_scope_required"

# === Convention Cops ===
require_relative "rubocop/cop/convention/prefer_symbol_json_access"
# require_relative "rubocop/cop/convention/frozen_string_literal" # Use Style/FrozenStringLiteralComment instead

# === RSpec Cops ===
require_relative "rubocop/cop/rspec/prefer_build_stubbed_for_non_persisted"
require_relative "rubocop/cop/rspec/service_requires_tenant_setup"
require_relative "rubocop/cop/rspec/prefer_let_over_instance_variable"
require_relative "rubocop/cop/rspec/prefer_shared_context"
require_relative "rubocop/cop/rspec/flaky_time_patterns"
require_relative "rubocop/cop/rspec/test_data_ordering"
require_relative "rubocop/cop/rspec/aggregate_failures"

# === FactoryBot Cops ===
require_relative "rubocop/cop/factory_bot/explicit_tenant_handling"

# === Cucumber Cops ===
require_relative "rubocop/cop/cucumber/consistent_wait_timeout"
require_relative "rubocop/cop/cucumber/prefer_have_over_has_css"
require_relative "rubocop/cop/cucumber/prefer_atomic_steps"
require_relative "rubocop/cop/cucumber/no_silent_database_rescue"
require_relative "rubocop/cop/cucumber/prefer_test_id"
require_relative "rubocop/cop/cucumber/no_sleep_in_cucumber"
