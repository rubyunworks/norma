# XMLProver/Ruby - Prover
# Copyright (c) 2002 Thomas Sawyer, Ruby License


require 'xmlproof/proofsheet'
require 'parsedate'

module XMLProof

	# Validator class
	class Validator
	
		attr_reader :valid, :errors

		def initialize
			@valid = nil
			@errors = nil
		end

		# Validates an XML document aginst its internally specified schemas.
		def valid?(xml)
			@xml_source = REXML::SourceFactory.create_from(xml)
			@xml_document = REXML::Document.new(@xml_source)
			@proofset = Document_ProofSet.new(@xml_document)
			validate_document  # return @valid
		end

		
		private  # --------------------------------------------------
		
		# Validate document, automatically started when object is initiated
		def validate_document
			@running_count = Hash.new(0)
			@running_option = Hash.new(0)
			@errors = []
			validate_recurse(@xml_document.root, "")
			@valid = @errors.empty?  # return @valid
		end
		
		# Resursive validator method
		def validate_recurse(element, path)
			# building xpath
			if path.empty?
				xpath = element.name  # root element
			else
				xpath = path + "/" + element.name
			end
			# validate attributes
			if element.has_attributes?
				element.attributes.each_attribute do |attribute|
					#puts attribute
					attribute_xpath = xpath + "/@" + attribute.name
					# validate attribute against die
					die = @proofset.die(attribute.inherited_namespace, attribute_xpath)
					if die
						# validate attribuite against regexp
						md = die.regexp.match(attribute.value)
						if not md
							error = "RANGE:'#{attribute.value}'!~/#{die.regexp.source}/"
							@errors << [xpath, attribute.inherited_namespace, error]
						end
						# validate element against datatype
						if not die.typecast(attribute.value)
						  error = "DATATYPE:'#{attribute.value}'::#{die.datatype}"
							@errors << [xpath, attribute.inherited_namespace, error]
						end
					else
						# ????? what if there were no die for this xpath
					end
				end
			end
			#
			if element.has_elements?
				# validate element against order
				order = @proofset.order(element.inherited_namespace, xpath)
				if order
					# load childern element tag names into an array
					ordered_children = []
					element.elements.each do |child_element|
						ordered_children << child_element.name
					end
					# are they properly ordered?
					children_index = 0
					order_index = 0
					while children_index < ordered_children.size and order_index < order.size
						if ordered_children[children_index] == order[order_index]
							children_index += 1
						else
							order_index += 1
						end
					end
					# if through the order array first its b/c we got stuck on a misplaced child
					if order_index >= order.size
						error = "ORDER:#{ordered_children[children_index]}"
						@errors << [xpath, element.inherited_namespace, error]
					end
				end
				# now validate all children
				element.elements.each do |el|
					validate_recurse(el, xpath)  # RECURSE
				end
			else
				# validate element against die
				die = @proofset.die(element.inherited_namespace, xpath)
				if die
					# validate element against regexp
					md = die.regexp.match(element.text)
					if not md
						error = "RANGE:'#{element.text}'!~/#{die.regexp.source}/"
						@errors << [xpath, element.inherited_namespace, error]
					end
					# validate element against datatype
					if not die.typecast(element.text)
						error = "DATATYPE:'#{element.text}'::#{die.datatype}"
						@errors << [xpath, element.inherited_namespace, error]
					end
				else
				  # ????? what if there were no die for this xpath
				end
				# validate element againt count
				count = @proofset.count(element.inherited_namespace, xpath)
				if count
					@running_count[xpath] += 1
					if not count === @running_count[xpath]
						error = "COUNT:#{count}"
						@errors << [xpath, element.inherited_namespace, error]
					end
				end
				# validate element againt option
				option = @proofset.option(element.inherited_namespace, xpath)
				if option
					@running_option[option] += 1
					if @running_option[option] > 1
						error = "OPTION:#{option}"
						@errors << [xpath, element.inherited_namespace, error]
					end
				end
			end
			return errors
		end
		
	end # class Validator

end	 # XMLProof
