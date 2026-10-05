module RunsHelper
  # "claude-opus-5-5[1m]" reads as "Opus 5.5 1M"; a dated id drops its date; aliases such as "opus" read as "Opus".
  def model_label(model)
    return Run::MODELS[model] if Run::MODELS.key?(model)

    context = model[/\[(\w+)\]\z/, 1]
    family, *parts = model.delete_prefix("claude-").sub(/\[\w+\]\z/, "").split("-")
    version = parts.take_while { it.match?(/\A\d{1,2}\z/) }.join(".")
    [ family.capitalize, version.presence, context&.upcase ].compact.join(" ")
  end

  # [label, value, note]. The session's own model comes first and stands in for its family's alias,
  # so "Opus 5.5" and "Opus" don't both appear.
  def model_options(conversation)
    session = conversation.last_model
    if session && !Run::MODELS.key?(session)
      family = session.delete_prefix("claude-").split("-").first
      [ [ model_label(session), session, "This session" ] ] +
        Run::MODELS.except(family).map { |value, label| [ label, value, "Latest #{label}" ] }
    else
      [ [ "Default", "", "Your Claude Code default" ] ] + Run::MODELS.map { |value, label| [ label, value, "Latest #{label}" ] }
    end
  end

  def effort_options
    [ [ "Default", "" ] ] + Run::EFFORTS.map { [ it, it ] }
  end

  def run_options_summary(model:, effort:, permission_mode:)
    [ model.present? ? model_label(model) : "Default model", effort.presence, Run::PERMISSION_MODES[permission_mode] ].compact.join(" · ")
  end
end
