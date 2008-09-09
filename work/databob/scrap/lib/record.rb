# DORM FORM NORM OORM QORM VORM WORM XORM YORM ZORM

module Recordable

  # RecordReader
  #
  # Description: >
  #
  #   Reader methods for ORM
  #
  # Optional singleton methods: >
  #
  #   sql_where()
  #   load_exclude()
  #
  # Provides: >
  #
  #   load_from_database()
  #   load_related_from_database()
  #
  module RecordReader

    def load_from_database
      r = self.class.connection.select_one(self.sql_select)
      if r
        ### need to clean up the results, for example dates are DBI dates
        self.write_by_hash(r.to_h)
        success = true
      else
        success = false
      end
      success
    end
 
    def load_related_from_database
      # if depth > 0 ?
      # find all instance valiables that match my_* and my_*_collection
      ho = instace_variables.collect { |iv| iv =~ /^my_.+$/ }
      hc = instace_variables.collect { |iv| iv =~ /^my_.+_collection$/ }
      ho.each { |hor| hor.load_from_database if hor.respond_to?(:load_from_database) }
      hc.each { |hcr|
        hcr.each { |hcri| 
          hcri.load_from_database if hcri.respond_to?(:load_from_database)
        } 
      }
    end

    def sql_select
      tbl = self.class.table
      keyf = self.class.primary_key
      keyv = send(keyf.intern).to_i
      le = respond_to?(:load_exclude) ? (load_exclude || []) : []
      if le.empty?
        sql = "SELECT * FROM #{tbl}"
        if respond_to?(:sql_where)
          sql << " WHERE #{sql_where}"
        else
          sql << " WHERE #{keyf}=#{keyv}"
        end
      else
        self.class.connection.meta.fields[tbl].each { |name|
          if respond_to?(name) and not le.include?(name)
            new_value = send(name)
            fields << name
          end
          fields << keyf if not fields.include?(keyf)
        }
        if not fields.empty?
          sql = "SELECT " << fields.join(',') << " FROM #{tbl}"
          if respond_to?(:sql_where)
            sql << " WHERE #{sql_where}"
          else
            sql << " WHERE #{keyf}=#{keyv}"
          end
        else
          raise "no attribute of the object cooresponds to the load query. that's useless!"
        end
      end
      return sql
    end
  end
  
  
  # RecordWriter
  #
  # Description: >
  #
  #   Writer methods for ORM
  #
  # Optional singleton methods: >
  #
  #   update_exclude()
  #   insert_exclude()
  #
  # Provides: >
  #
  #   update_database()
  #   insert_into_database()
  #   delete_from_database()
  #
  #   mark()
  #   mark()=
  #
  module RecordWriter
    
    #attr_accessor :mark => :to_b

    #
    def update_database  #(depth=1)
      success = nil
      sql = nil
      dbh = self.class.connection
      tbl = self.class.table
      keyf = self.class.primary_key
      keyv = send(keyf.intern).to_i
      # make sure we have a record to update
      r = dbh.select_one(sql_select)
      raise "cannot update, record not found" if not r
      # collect fields with values that have changed
      ue = respond_to?(:update_exclude) ? update_exclude : []
      fields = []
      r.each { |name, value|
        if respond_to?(name.intern) and name.to_s != keyf and not ue.include?(name)
          new_value = self.send(name.intern)
          fields << [name, new_value] if new_value != value
        end
      }
      # build update sql
      if not fields.empty?
        sql = "UPDATE #{tbl} SET " 
        #sql << fields.collect{ |p| "#{p[0]}=#{dbh.sql_format(tbl, p[0], p[1])}" }.join(',')
        sql << fields.collect{ |p| "#{p[0]}=#{dbh.quote(p[1])}" }.join(',')
        sql << " WHERE #{keyf}=#{keyv}"
      end
      # update
      if sql
        dbh.begin_db_transaction
        begin
          dbh.update(sql)
          # related recordsets ?
          #if depth > 0
          #  self.related_recordsets.each { |rrs| rrs.update_database(depth - 1) }
          #end
        rescue
          dbh.rollback_db_transaction
          success = false
          raise  # ?
        else
          dbh.commit_db_transaction
          success = true
        end
      end
      success
    end

    #
    def insert_into_database  #(depth=1)
      new_key = nil
      sql = nil
      dbh = self.class.connection
      tbl = self.class.table
      keyf = self.class.primary_key
      keyv = send(keyf.intern).to_i
      fields = []
      dbh.meta.fields[tbl].each { |name|
        if respond_to?(name.intern) and name.to_s != keyf and not insert_exclude.include?(name)
          new_value = send(name.intern)
          fields << [name, new_value]
        end
      }
      if not fields.empty?
        sql = "INSERT INTO #{tbl} (" 
        sql << fields.collect{ |p| p[0] }.join(',') 
        sql << ') VALUES (' 
        #sql << fields.collect{ |p| dbh.sql_format(tbl, p[0], p[1]) }.join(',')
        sql << fields.collect{ |p| dbh.quote(p[1]) }.join(',') 
        sql << ')'
      end
      if sql
        dbh.begin_db_transaction
        begin
          new_key = dbh.insert(sql)
          
          ### CURRENTLY THIS ONLY WORKS WITH PG DBD!!!!!!!!
          ### REMOVE THANKS TO ACTIVE RECORD DB ADAPTERS
          #sql = "SELECT currval('#{tbl}_#{keyf}_seq') as new_key"
          #new_key = dbh.select_one(sql)['new_key']
          #self.send("#{keyf}=".intern, new_key)
          
          #if depth > 0 ?
          #  # related recordsets
          #  related_recordsets.each { |rrs| rrs.update_database(depth - 1) }
          #end
        rescue
          self.dbh.rollback_db_transaction
          success = false
        else
          self.dbh.commit_db_transaction
          success = true
        end
      end
      return new_key
    end

    #
    def delete_from_database
      success = nil
      dbh = self.class.connection
      tbl = self.class.table
      keyf = self.class.primary_key
      keyv = send(keyf.intern).to_i
      sql = "DELETE FROM #{tbl} WHERE #{keyf}=#{keyv}"
      dbh.begin_db_transaction
      begin
        dbh.delete(sql)
        # related records?
      rescue
        dbh.rollback_db_transaction
        success = false
        #raise  # ?
      else
        dbh.commit_db_transaction
        success = true
      end
      success
    end
  
  end  # Record

end  # Recordable



=begin

    #
    #
    #

    #protected

    #def record_identity
    #  tbl = class.table self.respond_with_value(:parent).kind_of?(DBIze::Recordset) ? parent.table : self.table
    #  keyf = self.respond_with_value(:parent).kind_of?(DBIze::Recordset) ? parent.primary_key : self.primary_key
    #  keyv = self.send(keyf.intern).to_i
    #  return tbl, keyf, keyv
    #end

  end

  # ***
    
  #
  ###
  #

  # RecordsetReader
  #   Mixin module that links a DBIzed object in a one-to-many relationship with other DBIzed objects.
  #   This module must be included into a subclass of Array!
  #
  # Requires:
  #
  #   connection - method returns an array of database [dsn, username, password, optional-parameters-hash ]
  #   sql_select -
  #   set_class - returns the class constant of the record's being stored
  #
  # (optional if a recordset of a record)
  #   parent - return the record object that holds these subrecords
  #
  # Provides:
  #
  #   dbh()
  #   load_from_database()
  #

    module RecordsetReader

      attr_accessor :sql_select

      def dbh
        return DBI.instance(*self.connection)
      end

      def load_from_database(depth=0, *args)
        self.clear
        rs = self.dbh.select_all(self.sql_select)
        return [] if not rs
        self.load_from_array(rs, *args)
        if depth > 0
          self.each do |r|
            #r.related_views.each { |rv| rv.load_from_database(depth - 1) if rv != self.parent }
            r.related_views.each do |rr|
              if rr != self.parent
                if rr.kind_of?(Ize::Record)
                  pk = r.send(pr.references.intern).to_i
                  pr.send("#{rr.primary_key}=".intern, pk)
                end
                pr.load_from_database(depth - 1)
              end
            end
            r.related_viewsets.each { |rvs| rvs.load_from_database(depth - 1) if rvs != self }
            #r.related_recordsets.each { |rrs| rrs.load_from_database(depth - 1) if sr != self }
          end
        end
      end

    end

    #
    ###
    #

    # Recordset
    #   Mixin module that links a DBIzed object in a one-to-many relationship with other DBIzed objects.
    #   This module must be included into a subclass of Array!
    #
    # Object Requires:
    #
    #   connection() - method returns an array of database [dsn, username, password, optional-parameters-hash ]
    #   table() - the table these subrecords are stored in
    #   primary_key() - method returns record id field name of the table
    #   set_class() - returns the class constant of the record's being stored
    #
    # (optional)
    #   left_join() -  optional, returns a three element array of: table name, select-hash, and on-hash
    #   order_by() - optional, sorts the loaded records by field or fields if an array
    #
    # (optional, req. if a recordset of a record)
    #   parent() - return the record object that holds these subrecords
    #   references() - returns a hash with keys of database field names that link the subrecord to the record and values
    #                  that are symbols for the parent methods to retrieve those field's values.
    #
    # Provides:
    #
    #   update_database()
    #

    module Recordset

      include DBIze::Viewset

      attr_accessor :connection,
                    :table,
                    :primary_key,
                    :references,
                    :sql_where,
                    :left_join,
                    :order_by,
                    :load_exclude,
                    :update_exclude,
                    :insert_exclude

      def update_database(depth=0)

        self_recids = self.collect { |sr| sr.send(self.primary_key.intern) }

        sql = "SELECT * FROM #{self.table}"
        sql << " WHERE " if self.references or self.sql_where
        if self.references
          sql << self.references.collect { |f, p|
            "#{f}=#{self.dbh.sql_format(self.table, f, ( p.kind_of?(Symbol) ? self.parent.send(p) : p ))}"
          }.join(' AND ')
          sql << " AND " if self.sql_where
        end
        if self.sql_where
          sql << "#{self.sql_where}"
        end

        sql.gsub!(/\s*=\s*NULL/, ' IS NULL')
        db_recs = self.dbh.select_all(sql)
        db_recids = db_recs.collect { |r| r[self.primary_key.to_s] }

        upd_ids = db_recids & self_recids
        del_ids = db_recids - self_recids

        dummy = self.set_class.new  # use a dummy record to get respond_to? info

        flds = self.dbh.meta.fields[self.table].find_all { |f|  dummy.respond_to?(f.intern) and f.intern != self.primary_key.intern }
        if self.update_exclude
          flds = flds - self.update_exclude
        end
        upd_sth = self.dbh.prepare("UPDATE #{self.table} SET #{flds.collect { |f| "#{f}=?" }.join(', ')} WHERE #{self.primary_key}=?")
        del_sth = self.dbh.prepare("DELETE FROM #{self.table} WHERE #{self.primary_key}=?")
        ins_sth = self.dbh.prepare("INSERT INTO #{self.table} (#{flds.join(', ')}) VALUES (#{(["?"] * flds.length).join(', ')})")

        self.dbh.transaction do
          # updates or inserts
          self.each do |sr|
            rid = sr.send(self.primary_key.intern)
            if upd_ids.include?(rid)
              upd_flds = flds.collect { |f| sr.send(f.intern) } << rid
              upd_sth.execute(*upd_flds)
            else
              ins_sth.execute(*flds.collect { |f| sr.send(f.intern) })
            end
          end
          # deletes
          del_ids.each { |did| del_sth.execute(did) }
          self.dbh.commit
        end
        self.load_from_database(depth)

      end

      protected

      def sql_select
        #ref_hash = {}
        #if respond_with_value(:references)
        #  self.references.each { |f, p| ref_hash.update({ f => p.kind_of?(Symbol) ? self.parent.send(p.intern) : p }) }
        #end
        #@__dbize_where__ = ref_hash
        if self.left_join
          lj_arr = self.left_join
          lj_select = ", " << lj_arr[1].collect { |c, p| "#{lj_arr[0]}.#{p} AS #{c}" }.join(', ')
          lj_from = " LEFT JOIN #{lj_arr[0]}"
          lj_from << " ON " << lj_arr[2].collect { |f, p| "#{self.table}.#{f}=#{lj_arr[0]}.#{p}" }.join(' AND ')
        else
          lj_select = ''
          lj_from = ''
        end
        sql = "SELECT #{self.table}.*#{lj_select} FROM #{self.table}#{lj_from}"
        sql << " WHERE " if self.references or self.sql_where
        if self.references
          sql << self.references.collect { |f, p|
            "#{f}=#{self.dbh.sql_format(self.table, f, ( p.kind_of?(Symbol) ? self.parent.send(p) : p ))}"
          }.join(' AND ')
          sql << " AND " if self.sql_where
        end
        if self.sql_where
          sql << "#{self.sql_where}"
        end
        if self.order_by
          sql << " ORDER BY " << [ self.order_by ].flatten.join(',')
        end
        sql.gsub!(/\s*=\s*NULL/, ' IS NULL')
        return sql
      end
      
    end  # Recordset

=end

 
