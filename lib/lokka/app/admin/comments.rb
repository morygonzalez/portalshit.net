# frozen_string_literal: true

module Lokka
  class App
    namespace '/admin' do
      namespace '/comments' do
        get do
          @comments = Comment.order('created_at DESC').
                        page(params[:page]).
                        per(settings.admin_per_page)
          haml :'admin/comments/index', layout: :'admin/layout'
        end

        get '/new' do
          @comment = Comment.new
          haml :'admin/comments/new', layout: :'admin/layout'
        end

        post do
          @comment = Comment.new(params[:comment])
          if @comment.save
            flash[:notice] = t('comment_was_successfully_created')
            redirect to("/admin/comments/#{@comment.id}/edit")
          else
            haml :'admin/comments/new', layout: :'admin/layout'
          end
        end

        get '/:id/edit' do |id|
          (@comment = Comment.where(id: id).first) || raise(Sinatra::NotFound)
          haml :'admin/comments/edit', layout: :'admin/layout'
        end

        put '/:id' do |id|
          (@comment = Comment.where(id: id).first) || raise(Sinatra::NotFound)
          was_not_approved = @comment.status != Comment::APPROVED
          if @comment.update(params[:comment])
            if was_not_approved && @comment.status == Comment::APPROVED
              @comment.entry # preload association
              comment = @comment
              Thread.new do
                Lokka::CommentNotifier.new(comment).notify_commenter
              rescue => e
                $stderr.puts "Failed to send comment approval notification: #{e.message}"
              ensure
                ActiveRecord::Base.connection_pool.release_connection
              end
            end
            flash[:notice] = t('comment_was_successfully_updated')
            redirect to("/admin/comments/#{@comment.id}/edit")
          else
            haml :'admin/comments/edit', layout: :'admin/layout'
          end
        end

        delete '/spam' do
          Comment.spam.delete_all
          flash[:notice] = t('comment_was_successfully_deleted')
          redirect to('/admin/comments')
        end

        delete '/selected' do
          selected = params[:selected_comment_ids]&.split(',')
          Comment.where(id: selected).delete_all
          flash[:notice] = t('comment_was_successfully_deleted')
          redirect to('/admin/comments')
        end

        delete '/:id' do |id|
          (comment = Comment.where(id: id).first) || raise(Sinatra::NotFound)
          comment.destroy
          flash[:notice] = t('comment_was_successfully_deleted')
          redirect to('/admin/comments')
        end
      end
    end
  end
end
