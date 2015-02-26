//
//  SerializeOperation.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import SwiftyJSON

/**
*  A SerializeOperation is responsible for serializing resource into a multidimensional dictionary/array structure.
*  The resouces are converted to their serialized form using a layered process.
*
*  This process is the inverse of that of the DeserializeOperation.
*/
class SerializeOperation: NSOperation {
	private let resources: [ResourceProtocol]
	var transformers = TransformerDirectory()
	var options = SerializationOptions()
	
	var result: NSData?
	
	
	// MARK: Initializers
	
	init(resources: [ResourceProtocol]) {
		self.resources = resources
	}
	
	
	// MARK: NSOperation
	
	override func main() {
		if resources.count == 1 {
			let serializedData = serializeResource(resources.first!)
			result = NSJSONSerialization.dataWithJSONObject(["data": serializedData], options: NSJSONWritingOptions(0), error: nil)
			
		} else  {
			var data = resources.map { resource in
				self.serializeResource(resource)
			}
			
			result = NSJSONSerialization.dataWithJSONObject(["data": data], options: NSJSONWritingOptions(0), error: nil)
		}
	}
	
	
	// MARK: Serializing
	
	private func serializeResource(resource: ResourceProtocol) -> [String: AnyObject] {
		var serializedData: [String: AnyObject] = [:]
		
		// Serialize ID
		if options.includeID {
			if let ID = resource.id {
				serializedData["id"] = ID
			}
		}
		
		// Serialize type
		serializedData["type"] = resource.type
		
		// Serialize fields
		addAttributes(&serializedData, resource: resource)
		addRelationships(&serializedData, resource: resource)
		
		return serializedData
	}

	
	// MARK: Attributes
	
	/**
	Adds the attributes of the the given resource to the passed serialized data.
	
	This method loops over all the attributes in the passed resource, maps the attribute name
	to the key for the serialized form and formats the value of the attribute. It then passes
	the key and value to the addAttribute method.
	
	:param: serializedData The data to add the attributes to.
	:param: resource       The resource whose attributes to add.
	*/
	private func addAttributes(inout serializedData: [String: AnyObject], resource: ResourceProtocol) {
		for attribute in resource.attributes {
			if attribute is RelationshipAttribute {
				continue
			}
			
			//TODO: Dirty checking
			
			let key = attribute.serializedName
			
			if let unformattedValue: AnyObject = resource.valueForAttribute(attribute.name) {
				addAttribute(&serializedData, key: key, value: self.transformers.serialize(unformattedValue, forAttribute: attribute))
			} else {
				addAttribute(&serializedData, key: key, value: NSNull())
			}
		}
	}
	
	/**
	Adds the given key/value pair to the passed serialized data.
	
	:param: serializedData The data to add the key/value pair to.
	:param: key            The key to add to the serialized data.
	:param: value          The value to add to the serialized data.
	*/
	private func addAttribute(inout serializedData: [String: AnyObject], key: String, value: AnyObject) {
		serializedData[key] = value
	}
	
	
	// MARK: Relationships
	
	/**
	Adds the relationships of the the given resource to the passed serialized data.
	
	This method loops over all the relationships in the passed resource, maps the attribute name
	to the key for the serialized form and gets the related attributes. It then passes the key and
	related resources to either the addToOneRelationship or addToManyRelationship method.
	
	
	:param: serializedData The data to add the relationships to.
	:param: resource       The resource whose relationships to add.
	*/
	private func addRelationships(inout serializedData: [String: AnyObject], resource: ResourceProtocol) {
		for attribute in resource.attributes {
			let key = attribute.serializedName
			
			switch attribute {
			case let toOne as ToOneAttribute:
				if options.includeToOne {
					addToOneRelationship(&serializedData, key: key, type: toOne.linkedType, linkedResource: resource.valueForAttribute(attribute.name) as? ResourceProtocol)
				}
			case let toMany as ToManyAttribute:
				if options.includeToMany {
					addToManyRelationship(&serializedData, key: key, type: toMany.linkedType, linkedResources: resource.valueForAttribute(attribute.name) as? ResourceCollection)
				}
			default: ()
			}
		}
	}
	
	/**
	Adds the given resource as a to to-one relationship to the serialized data.
	
	:param: serializedData  The data to add the related resource to.
	:param: key             The key to add to the serialized data.
	:param: relatedResource The related resource to add to the serialized data.
	*/
	private func addToOneRelationship(inout serializedData: [String: AnyObject], key: String, type: String, linkedResource: ResourceProtocol?) {
		let serializedRelationship = [
			"type": type,
			"id": linkedResource?.id ?? NSNull()
		]
		
		if serializedData["links"] == nil {
			serializedData["links"] = [key: serializedRelationship]
		} else {
			var links = serializedData["links"] as [String: AnyObject]
			links[key] = serializedRelationship
			serializedData["links"] = links
		}
	}
	
	/**
	Adds the given resources as a to to-many relationship to the serialized data.
	
	:param: serializedData   The data to add the related resources to.
	:param: key              The key to add to the serialized data.
	:param: relatedResources The related resources to add to the serialized data.
	*/
	private func addToManyRelationship(inout serializedData: [String: AnyObject], key: String, type: String, linkedResources: ResourceCollection?) {
		var serializedIDs: AnyObject = []
		
		if let resources = linkedResources?.resources {
			let IDs: [String] = resources.filter { $0.id != nil }.map { $0.id! }
			serializedIDs = IDs
		}
		
		let serializedRelationship = [
			"type": type,
			"ids": serializedIDs
		]
		
		if serializedData["links"] == nil {
			serializedData["links"] = [key: serializedRelationship]
		} else {
			var links = serializedData["links"] as [String: AnyObject]
			links[key] = serializedRelationship
			serializedData["links"] = links
		}
	}
}