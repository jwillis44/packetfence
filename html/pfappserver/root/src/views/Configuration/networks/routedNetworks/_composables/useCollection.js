import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Routed Network <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Routed Network <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Routed Network')
    }
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('wmiRules', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
      locked: true
    },
    {
      key: 'id',
      label: 'WMI Rule', // i18n defer
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'namespace',
      label: 'Namespace', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'on_tab',
      label: 'On Node Tab', // i18n defer
      sortable: true,
      visible: true
    },

    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    },
    {
      key: 'not_deletable',
      required: true,
      visible: false
    }
  ],
  fields: [
    {
      value: 'id',
      text: i18n.t('WMI Rule'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'namespace',
      text: i18n.t('Namespace'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id',
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [
      { field: 'id', op: 'not_equals', value: null }
    ] }
  ] })
})
