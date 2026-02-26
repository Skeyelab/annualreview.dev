module Api
  class ReviewYearsController < ApplicationController
    before_action :require_auth!

    def index
      years = current_user.review_years.order(year: :desc)
      render json: years.map { |ry| review_year_json(ry) }
    end

    def show
      ry = current_user.review_years.find_by(year: params[:year])
      return render json: { error: "Not found" }, status: :not_found unless ry
      render json: review_year_json(ry)
    end

    def update
      ry = current_user.review_years.find_or_initialize_by(year: params[:year].to_i)
      ry.goals = params[:goals] if params.key?(:goals)
      ry.start_date = params[:start_date] if params.key?(:start_date)
      ry.end_date = params[:end_date] if params.key?(:end_date)
      if ry.save
        render json: review_year_json(ry)
      else
        render json: { errors: ry.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def review
      ry = current_user.review_years.find_by(year: params[:year])
      return render json: { error: "Not found" }, status: :not_found unless ry
      return head :no_content if ry.pipeline_result.blank?

      md = MarkdownGenerator.generate(
        ry.pipeline_result,
        timeframe: { start_date: ry.start_date, end_date: ry.end_date },
        goals: ry.goals
      )
      render json: { pipeline_result: ry.pipeline_result, markdown: md, generated_at: ry.pipeline_result_at }
    end

    private

    def review_year_json(ry)
      {
        year: ry.year,
        start_date: ry.start_date,
        end_date: ry.end_date,
        goals: ry.goals,
        evidence_updated_at: ry.evidence_updated_at,
        pipeline_result_at: ry.pipeline_result_at,
        has_evidence: ry.evidence.present?,
        has_pipeline_result: ry.pipeline_result.present?
      }
    end
  end
end
