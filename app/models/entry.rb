# Entries are CRUDed Contents
# (CRUD: http://en.wikipedia.org/wiki/Create,_read,_update_and_delete)
#
# A Entry is created when an Agent entries a Content to a Container
#
# == Named Scopes
# content_type:: Select Entries which content_type is the param. Example:
#   Entry.content_type(:articles) #=> entries which content is an Article
class Entry < ActiveRecord::Base
  acts_as_sortable
  acts_as_container :name => :title

  # Pagination (will_paginate gem)
  cattr_reader :per_page
  @@per_page = 15

  # Collection name
  # See Content
  cattr_reader :collection
  @@collection = :entries

  belongs_to :content,   :polymorphic => true
  belongs_to :container, :polymorphic => true
  belongs_to :agent,     :polymorphic => true

  has_many :categorizations,
             :dependent => :destroy
  has_many :categories,
           :through => :categorizations


  validates_presence_of :title, 
                        :agent_id,
                        :agent_type,
                        :content_id, 
                        :content_type,
                        :container_id, 
                        :container_type
  validates_associated  :content

  # ContentType named scope
  named_scope :content_type, lambda { |content_type|
    return Hash.new if content_type.blank?

    content_sym = content_type.to_s.tableize.to_sym
    return Hash.new unless CMS.contents.include?(content_sym)
    content_class = content_sym.to_class
    
    from, conditions = if content_class.column_names.include?("type")
                         # Content has STI
                         [ "#{ content_class.table_name }, entries", 
                           [ "entries.content_id = #{ content_class.table_name }.id AND entries.content_type = ? AND #{ content_class.table_name }.type = ?", content_class.table_name.classify, content_class.to_s ] ]
                       else
                         [ "entries", 
                           [ "entries.content_type = ?", content_class.to_s ] ]
                       end

    { :select => "entries.*", :from => from, :conditions => conditions }
  }

  # True if the associated Content of this Entry has media
  def has_media?
    ! content.content_options[:has_media].nil?
  end

  # Can the Entry be read by <tt>agent</tt>?
  def read_by?(agent = :false)
    public_read? || container.has_role_for?(agent, :read_entries)
  end

  # Can the Entry be modified by <tt>agent</tt>?
  def update_by?(agent = :false)
    public_write? || container.has_role_for?(agent, :update_entries)
  end

  # Set Entry Categories by it id
  def category_ids=(cids)
    cids ||= []
    #FIXME: optimize
    categorizations.map(&:destroy)
    for cid in cids
      categories << Category.find(cid)
    end
  end
end