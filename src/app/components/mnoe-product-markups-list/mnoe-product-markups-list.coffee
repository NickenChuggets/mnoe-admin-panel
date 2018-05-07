#
# Mnoe product markup list
#
@App.component('mnoeProductMarkupsList', {
  templateUrl: 'app/components/mnoe-product-markups-list/mnoe-product-markups-list.html',
  bindings: {
    view: '@'
    customerOrg: '<'
  }
  controller: ($filter, $log, $translate, MnoeProductMarkups, MnoeCurrentUser, MnoConfirm, MnoeObservables, OBS_KEYS, toastr) ->
    vm = this

    vm.markups =
      editmode: []
      search: {}
      sort: "product.name"
      nbItems: 10
      offset: 0
      page: 1
      list: []
      widgetTitle: 'mnoe_admin_panel.dashboard.product_markups.widget.list.title'
      pageChangedCb: (nbItems, page) ->
        vm.markups.nbItems = nbItems
        vm.markups.page = page
        offset = (page  - 1) * nbItems
        fetchProductMarkups(nbItems, offset)
    vm.readOnlyView = false

    # Manage sorting, search and pagination
    vm.callServer = (tableState) ->
      sort   = updateSort (tableState.sort)
      search = updateSearch (tableState.search)
      fetchProductMarkups(vm.markups.nbItems, vm.markups.offset, sort, search)

    # Update sorting parameters
    updateSort = (sortState = {}) ->
      sort = "product.name"
      if sortState.predicate
        sort = sortState.predicate
        if sortState.reverse
          sort += ".desc"
        else
          sort += ".asc"

      # Update markups sort
      vm.markups.sort = sort
      return sort

    # Update searching parameters
    updateSearch = (searchingState = {}) ->
      search = {}
      if searchingState.predicateObject
        for attr, value of searchingState.predicateObject
          if _.isObject(value)
            # Workaround to allow 'relation.field' type of search
            # 'product.name' search for 'a' is interpreted by Smart Table as {product: {name: 'a'}
            search[ 'where[' + attr + '.' + _.keys(value)[0] + '.like]' ] = _.values(value)[0] + '%'
          else
            search[ 'where[' + attr + '.like]' ] = value + '%'

      # Update markups sort
      vm.markups.search = search
      return search

    # Fetch markups
    fetchProductMarkups = (limit, offset, sort = vm.markups.sort, search = vm.markups.search) ->
      vm.markups.loading = true
      if vm.customerOrg
        vm.readOnlyView = true
        search[ 'where[for_organization]' ] = vm.customerOrg.id
      return MnoeProductMarkups.markups(limit, offset, sort, search).then(
        (response) ->
          vm.markups.totalItems = response.headers('x-total-count')
          vm.markups.list = response.data
      ).finally(-> vm.markups.loading = false)

    vm.update = (pm) ->
      pm.isSaving = true
      MnoeProductMarkups.updateProductMarkup(pm).then(
        (response) ->
          updateSort()
          updateSearch()
          # Remove the edit mode for this user
          delete vm.editmode[pm.id]
        (error) ->
          # Display an error
          $log.error('Error while saving product markup', error)
          toastr.error('mnoe_admin_panel.dashboard.product_markups.add_markup.modal.toastr_error')
      ).finally(-> pm.isSaving = false)

    vm.remove = (pm) ->
      modalOptions =
        closeButtonText: 'mnoe_admin_panel.dashboard.product_markups.modal.remove_product_markup.cancel'
        actionButtonText: 'mnoe_admin_panel.dashboard.product_markups.modal.remove_product_markup.delete'
        headerText: 'mnoe_admin_panel.dashboard.product_markups.modal.remove_product_markup.proceed'
        bodyText: 'mnoe_admin_panel.dashboard.product_markups.modal.remove_product_markup.perform'

      MnoConfirm.showModal(modalOptions).then( ->
        pm.isSaving = true
        MnoeProductMarkups.deleteProductMarkup(pm).then( ->
          updateSort()
          updateSearch()
          toastr.success('mnoe_admin_panel.dashboard.product_markups.modal.remove_product_markup.toastr_success')
        ).finally(-> pm.isSaving = false)
      )

    vm.showOrgName = (name) ->
      return $translate.instant("mnoe_admin_panel.dashboard.product_markups.add_markup.modal.all_companies") unless name

      if vm.readOnlyView
        $translate.instant("mnoe_admin_panel.dashboard.product_markups.add_markup.modal.customer_specific")
      else
        name

    vm.customerHeader = ->
      if vm.readOnlyView
        "mnoe_admin_panel.dashboard.product_markups.widget.list.table.markup_type"
      else
        "mnoe_admin_panel.dashboard.product_markups.widget.list.table.customer"

    onChange = ->
      fetchProductMarkups(vm.markups.nbItems, vm.markups.offset)

    # Notify me if changes are made
    MnoeObservables.registerCb(OBS_KEYS.changesMade, onChange)

    this.$onDestroy = ->
      MnoeObservables.unsubscribe(OBS_KEYS.changesMade, onMarkupAdded)

    return

})
