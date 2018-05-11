@App.controller 'OrderController', ($filter, $state, $stateParams, $uibModal, toastr, MnoeProvisioning, MnoeOrganizations, MnoeUsers, MnoConfirm, MnoeProducts, MnoeCurrentUser) ->
  'ngInject'
  vm = this

  vm.subscriptionId = $stateParams.subscriptionId
  vm.orgId = $stateParams.orgId
  vm.orderId = $stateParams.orderId
  vm.order = {}
  vm.subscription = {}
  vm.rootName = $filter('translate')('mnoe_admin_panel.dashboard.order.root_name')
  vm.organization = {}
  vm.user = {}
  vm.isLoading = true
  vm.fulfillment_status = [
    {value: 'Y', text: 'mnoe_admin_panel.dashboard.order.fulfillment_yes'},
    {value: 'N', text: 'mnoe_admin_panel.dashboard.order.fulfillment_no'}
  ]

  # Configure user friendly json tree
  vm.jsonTreeSettings = {
    toggleBranchText: $filter('translate')('mnoe_admin_panel.dashboard.order.click_to_expand'),
    emptyValueText: $filter('translate')('mnoe_admin_panel.dashboard.order.no_data'),
    dateFormat: 'yyyy-MM-dd HH:mm:ss'
  }

  # If the user is viewing a specific #subscription_event(order), fetch it, otherwise show the user's non-obsolete #subscription_event
  if vm.orderId
    MnoeProvisioning.getSubscriptionEvent(vm.subscriptionId, vm.orgId, vm.orderId).then((response) ->
      vm.order = response.data.subscription_event
      )

  # Get the subscription
  MnoeProvisioning.fetchSubscription(vm.subscriptionId, vm.orgId).then(
    (response) ->
      vm.subscription = response.data.plain()
      vm.getInfo()
      if vm.subscription.externally_provisioned?
        MnoeProducts.fetchCustomSchema(vm.subscription.product.id).then((response) ->
          return unless response
          schema = JSON.parse(response)
          vm.schema = if schema.json_schema then schema.json_schema else {}
          vm.form = if schema.asf_options then schema.asf_options else ["*"]
      )
    ).finally(-> vm.isLoading = false)

  fetchSubscriptionEvents = () ->
    MnoeProvisioning.getSubscriptionEvents(vm.subscriptionId, vm.orgId).then(
      (response) ->
        vm.subscriptionEvents = response.data.subscription_events
        # If the user is not viewing a specific order, show the non-obsolete subscription event.
        unless vm.orderId
          vm.order = _.find(response.data.subscription_events, (s) -> !s.obsolete)
    )

  fetchSubscriptionEvents()

  MnoeCurrentUser.getUser().then(
    (response) ->
      vm.isAccountManager = (response.admin_role == 'staff')
  )

  vm.getInfo = ->
    MnoeOrganizations.get(vm.orgId).then(
      (response) ->
        vm.organization = response.data.plain()
    )
    if vm.subscription.user_id?
      MnoeUsers.get(vm.subscription.user_id).then(
        (response) ->
          vm.user = response.data.plain()
      )

  vm.displayInfoTooltip = ->
    vm.order.status == 'aborted'

  # Admin can only accept a #subscription_event(i.e. order) when subscription event is requested.
  vm.disableApproval = ->
    (vm.order.status != 'requested')

  # Admin can only fulfill a subscription when subscription is in the provisioning state and is not externally provisioned.
  vm.disableFulfillApproval = ->
    vm.subscription.status != 'provisioning' || vm.subscription.externally_provisioned

  # Only disabled cancel if status is already cancelled
  vm.disableCancel = ->
    (vm.order.status != 'requested')

  vm.orderWorkflowExplanation = ->
    if vm.disableApproval()
      'mnoe_admin_panel.dashboard.subscriptions.modal.approve_disabled'

  vm.subscriptionWorkflowExplanation = ->
    if vm.disableFulfillApproval()
      'mnoe_admin_panel.dashboard.subscriptions.modal.fulfill_disabled'

  vm.approveOrder = ->
    modalOptions =
      closeButtonText: 'mnoe_admin_panel.dashboard.subscriptions.modal.approve_subscriptions.close'
      actionButtonText: 'mnoe_admin_panel.dashboard.subscriptions.modal.approve_subscriptions.cancel'
      headerText: 'mnoe_admin_panel.dashboard.subscriptions.modal.approve_subscriptions.proceed'
      bodyText: 'mnoe_admin_panel.dashboard.subscriptions.modal.approve_subscriptions.perform'
      bodyTextExtraData: {subscription_name: vm.subscription.product.name}
      actionCb: ->
        MnoeProvisioning.approveSubscriptionEvent({id: vm.order.id}).then(() ->
          fetchSubscriptionEvents()
          ).then(() ->
            toastr.success('mnoe_admin_panel.dashboard.subscriptions.modal.approve_subscriptions.toastr_success', {extraData: {subscription_name: vm.subscription.product.name}})
          ).catch(() ->
            toastr.error('mnoe_admin_panel.dashboard.subscriptions.modal.approve_subscriptions.toastr_error', {extraData: {subscription_name: vm.subscription.product.name}})
          )
    MnoConfirm.showModal(modalOptions)

  vm.fulfillOrder = ->
    modalOptions =
      closeButtonText: 'mnoe_admin_panel.dashboard.subscriptions.modal.fulfill_subscriptions.close'
      actionButtonText: 'mnoe_admin_panel.dashboard.subscriptions.modal.fulfill_subscriptions.cancel'
      headerText: 'mnoe_admin_panel.dashboard.subscriptions.modal.fulfill_subscriptions.proceed'
      bodyText: 'mnoe_admin_panel.dashboard.subscriptions.modal.fulfill_subscriptions.perform'
      bodyTextExtraData: {subscription_name: vm.subscription.product.name}
      actionCb: ->
        MnoeProvisioning.fulfillSubscription({organization_id: vm.orgId, id: vm.subscriptionId }).then(
          (response) ->
            angular.copy(response.data.subscription, vm.subscription)
            toastr.success('mnoe_admin_panel.dashboard.subscriptions.modal.fulfill_subscriptions.toastr_success', {extraData: {subscription_name: vm.subscription.product.name}})
          ->
            toastr.error('mnoe_admin_panel.dashboard.subscriptions.modal.fulfill_subscriptions.toastr_error', {extraData: {subscription_name: vm.subscription.product.name}})
        ).finally(() -> fetchSubscriptionEvents())

    MnoConfirm.showModal(modalOptions)

  vm.cancelOrder = ->
    modalOptions =
      closeButtonText: 'mnoe_admin_panel.dashboard.subscriptions.modal.cancel_subscriptions.close'
      actionButtonText: 'mnoe_admin_panel.dashboard.subscriptions.modal.cancel_subscriptions.cancel'
      headerText: 'mnoe_admin_panel.dashboard.subscriptions.modal.cancel_subscriptions.proceed'
      bodyText: 'mnoe_admin_panel.dashboard.subscriptions.modal.cancel_subscriptions.perform'
      bodyTextExtraData: {subscription_name: vm.subscription.product.name}
      type: 'danger'
      actionCb: ->
        MnoeProvisioning.rejectSubscriptionEvent({id: vm.order.id}).then(
          fetchSubscriptionEvents()
          ).then(() ->
            toastr.success('mnoe_admin_panel.dashboard.subscriptions.widget.list.toastr_success', {extraData: {subscription_name: vm.subscription.product.name}})
          ).catch(() ->
            toastr.error('mnoe_admin_panel.dashboard.subscriptions.widget.list.toastr_error', {extraData: {subscription_name: vm.subscription.product.name}})
          )
    MnoConfirm.showModal(modalOptions)

  vm.displayStatusInfo = ->
    modalInstance = $uibModal.open(
      templateUrl: 'app/views/orders/order-status-info-modal/order-status-info.html'
      controller: 'OrderInfoController'
      controllerAs: 'vm'
    )

  return vm
