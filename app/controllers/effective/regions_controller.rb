module Effective
  class RegionsController < ApplicationController
    respond_to :html, :json
    layout false

    def edit
      EffectiveRegions.authorized?(self, :edit, Effective::Region.new())

      # TODO: turn this into a cookie or something better.
      redirect_to request.url.gsub('/edit', '') + '?edit=true'
    end

    def update
      Effective::Region.transaction do
        region_params.each do |key, vals| # article_section_2_title => {:content => '<p></p>'}
          to_save = nil  # Which object, the regionable, or the region (if global) to save

          regionable, title = find_regionable(key)

          if regionable
            EffectiveRegions.authorized?(self, :update, regionable) # can I update the regionable object?

            region = regionable.regions.find { |region| region.title == title }
            region ||= regionable.regions.build(:title => title)

            to_save = regionable
          else
            region = Effective::Region.global.where(:title => title).first_or_initialize
            EffectiveRegions.authorized?(self, :update, region) # can I update the global region?

            to_save = region
          end

          region.content = cleanup(vals[:content])

          region.snippets.clear
          (vals[:snippets] || []).each { |snippet, vals| region.snippets[snippet] = vals }

          to_save.save!
        end

        render :text => '', :status => 200
        return
      end

      render :text => 'error', :status => :unprocessable_entity
    end

    def snippets
      EffectiveRegions.authorized?(self, :edit, Effective::Region.new())

      retval = {}
      EffectiveRegions.snippets.each do |snippet|
        retval[snippet.class_name] = { :dialog_url => snippet.snippet_dialog_url }
      end

      render :json => retval
    end

    def snippet # This is a GET.  CKEDITOR passes us data, we need to render the non-editable content
      klass = "Effective::Snippets::#{region_params[:name].try(:classify)}".safe_constantize

      if klass.present?
        @snippet = klass.new(region_params[:data])
        render :partial => @snippet.to_partial_path, :object => @snippet, :locals => {:snippet_preview => true}
      else
        render :text => "Missing class Effective::Snippets::#{region_params[:name].try(:classify)}"
      end
    end

    protected

    def find_regionable(key)
      regionable = nil
      title = nil

      if(class_name, id, title = key.scan(/(\w+)_(\d)_(\w+)/).flatten).present?
        regionable = (class_name.classify.safe_constantize).find(id) rescue nil
      end

      return regionable, (title || key)
    end

    # TODO: Also remove any trailing tags that have no content in them....<p></p><p></p>
    def cleanup(str)
      (str || '').tap do |str|
        str.gsub!("\n", '')
        str.strip!
      end
    end

    def region_params
      begin
        params.require(:effective_regions).permit!
      rescue => e
        params[:effective_regions]
      end
    end
  end
end

