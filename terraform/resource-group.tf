# AWS has no mandatory container like Azure's Resource Group. This is
# purely a visual/organizational aid — a saved query over resources
# matching the Project tag, so everything can be viewed from one
# screen in the console instead of searching service by service.
# Deleting this resource group does NOT delete the underlying
# resources; it only removes the grouped view.
resource "aws_resourcegroups_group" "main" {
  name = "rg-${var.prefix}"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Project"
          Values = [var.prefix]
        }
      ]
    })
  }

  tags = local.common_tags
}
