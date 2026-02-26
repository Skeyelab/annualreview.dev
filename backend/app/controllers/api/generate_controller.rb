module Api
  class GenerateController < ApplicationController
    before_action :require_auth!

    def create
      if evidence_in_body?
        create_from_evidence
      else
        create_from_year
      end
    end

    private

    def evidence_in_body?
      params.key?(:timeframe) || params.key?(:contributions)
    end

    def create_from_year
      year = params[:year].to_i
      ry = current_user.review_years.find_by(year: year)
      return render json: { error: "Review year not found" }, status: :not_found unless ry
      return render json: { error: "No evidence collected yet" }, status: :unprocessable_entity if ry.evidence.blank?

      enqueue_job(ry.id)
    end

    def create_from_evidence
      evidence = params.to_unsafe_h.slice(:timeframe, :contributions, :role_context_optional, :goals)

      unless evidence[:timeframe].is_a?(ActionController::Parameters) || evidence[:timeframe].is_a?(Hash)
        return render json: { error: "Invalid evidence: timeframe is required" }, status: :bad_request
      end

      tf = evidence[:timeframe]
      unless tf[:start_date].present? && tf[:end_date].present?
        return render json: { error: "Invalid evidence: timeframe must have start_date and end_date" }, status: :bad_request
      end

      unless evidence[:contributions].is_a?(Array)
        return render json: { error: "Invalid evidence: contributions array is required" }, status: :bad_request
      end

      job = GenerateJob.perform_later(nil, evidence.deep_stringify_keys)
      jid = job.provider_job_id || job.job_id
      Rails.cache.write("job:#{jid}", { status: "pending" }, expires_in: 1.hour)
      current_user.update_column(:latest_job_id, jid)
      render json: { job_id: jid }, status: :accepted
    end

    def enqueue_job(review_year_id)
      job = GenerateJob.perform_later(review_year_id)
      jid = job.provider_job_id || job.job_id
      Rails.cache.write("job:#{jid}", { status: "pending" }, expires_in: 1.hour)
      current_user.update_column(:latest_job_id, jid)
      render json: { job_id: jid }, status: :accepted
    end
  end
end
